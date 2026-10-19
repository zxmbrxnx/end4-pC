import QtQuick
import qs.modules.common
import qs.modules.common.functions as CF

ApiStrategy {
    property bool isReasoning: false
    property var toolCallState: ({})
    property bool toolCallEmitted: false
    readonly property string localImagePrefix: "__LOCAL_IMAGE_FILE__:"
    
    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        const hasPendingFile = (filePath && filePath.length > 0);

        let formattedMessages = [
            { role: "system", content: systemPrompt }
        ];

        for (let i = 0; i < messages.length; i++) {
            const message = messages[i];
            const isLastMessage = (i === messages.length - 1);

            if (message.functionCall && message.functionCall.name) {
                formattedMessages.push({
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": message.functionCall.id || `call_${i}`,
                        "type": "function",
                        "function": {
                            "name": message.functionCall.name,
                            "arguments": JSON.stringify(message.functionCall.args ?? {})
                        }
                    }]
                });
                continue;
            }

            if (message.functionName && message.functionName.length > 0 && message.functionResponse !== undefined) {
                formattedMessages.push({
                    "role": "tool",
                    "tool_call_id": message.functionCallID || message.functionCall?.id || `call_${i}`,
                    "content": message.functionResponse ?? ""
                });
                continue;
            }

            let imagePath = "";
            if (isLastMessage && hasPendingFile) {
                imagePath = CF.FileUtils.trimFileProtocol(filePath);
            } else if (message.localFilePath && message.localFilePath.length > 0) {
                imagePath = CF.FileUtils.trimFileProtocol(message.localFilePath);
            }

            if (imagePath.length > 0 && message.role === "user") {
                formattedMessages.push({
                    "role": message.role,
                    "content": [
                        {
                            "type": "text",
                            "text": message.rawContent
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": `${localImagePrefix}${imagePath}`
                            }
                        }
                    ]
                });
            } else {
                formattedMessages.push({
                    "role": message.role,
                    "content": message.rawContent
                });
            }
        }

        let baseData = {
            "model": model.model,
            "messages": formattedMessages,
            "stream": true,
            "tools": tools,
            "temperature": temperature,
        };
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function buildScriptFileSetup(filePath) {
        return "mkdir -p /tmp/quickshell/ai\n";
    }

    function finalizeScriptContent(scriptContent: string): string {
        if (!scriptContent.includes(localImagePrefix)) {
            return scriptContent;
        }

        const dataMarker = " --data '";
        const markerIndex = scriptContent.lastIndexOf(dataMarker);
        if (markerIndex === -1) return scriptContent;

        const beforeData = scriptContent.substring(0, markerIndex);
        let afterData = scriptContent.substring(markerIndex + dataMarker.length);
        if (afterData.endsWith("\n")) afterData = afterData.slice(0, -1);
        if (afterData.endsWith("'")) afterData = afterData.slice(0, -1);

        const jsonPayload = afterData.replace(/'\\''/g, "'");

        const curlCmdIndex = beforeData.lastIndexOf("curl ");
        const prefixBeforeCurl = beforeData.substring(0, curlCmdIndex);
        const curlCmd = beforeData.substring(curlCmdIndex);

        const pythonScriptPath = `${CF.FileUtils.trimFileProtocol(Directories.scriptPath)}/ai/prepare-openai-payload.py`;

        let res = "";
        res += prefixBeforeCurl;
        res += `cat << 'QUICKSHELL_AI_PAYLOAD_EOF' > /tmp/quickshell/ai/payload_template.json\n`;
        res += `${jsonPayload}\n`;
        res += `QUICKSHELL_AI_PAYLOAD_EOF\n\n`;
        res += `python3 '${pythonScriptPath}' /tmp/quickshell/ai/payload_template.json /tmp/quickshell/ai/payload.json\n\n`;
        res += `${curlCmd} --data-binary "@/tmp/quickshell/ai/payload.json"\n`;
        return res;
    }

    function emitToolCall(message) {
        if (toolCallEmitted) return {};
        const keys = Object.keys(toolCallState);
        if (keys.length === 0) return {};
        const call = toolCallState[keys[0]];
        if (!call || !call.name) return {};
        toolCallEmitted = true;
        let args = {};
        try {
            args = call.arguments ? JSON.parse(call.arguments) : {};
        } catch (e) {
            args = {};
        }
        const id = call.id || `call_${Date.now()}`;
        call.id = id;
        const annotation = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        message.rawContent += annotation;
        message.content += annotation;
        message.functionName = call.name;
        message.functionCall = { name: call.name, args: args, id: id };
        return { functionCall: { name: call.name, args: args, id: id } };
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // console.log("[AI] OpenAI: Data:", cleanData);
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            if (!toolCallEmitted && Object.keys(toolCallState).length > 0) {
                const call = emitToolCall(message);
                if (call.functionCall) return call;
            }
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            const choice = dataJson.choices?.[0];
            const deltaToolCalls = choice?.delta?.tool_calls;
            if (deltaToolCalls) {
                for (const tc of deltaToolCalls) {
                    const idx = tc.index ?? 0;
                    if (!toolCallState[idx]) toolCallState[idx] = { id: "", name: "", arguments: "" };
                    if (tc.id) toolCallState[idx].id = tc.id;
                    if (tc.function?.name) toolCallState[idx].name = tc.function.name;
                    if (tc.function?.arguments) toolCallState[idx].arguments += tc.function.arguments;
                }
            }

            const messageToolCalls = choice?.message?.tool_calls;
            if (messageToolCalls) {
                for (const tc of messageToolCalls) {
                    const idx = tc.index ?? 0;
                    if (!toolCallState[idx]) toolCallState[idx] = { id: "", name: "", arguments: "" };
                    if (tc.id) toolCallState[idx].id = tc.id;
                    if (tc.function?.name) toolCallState[idx].name = tc.function.name;
                    if (tc.function?.arguments) toolCallState[idx].arguments += tc.function.arguments;
                }
            }

            const finishReason = choice?.finish_reason;
            if (finishReason && finishReason !== "length" && Object.keys(toolCallState).length > 0) {
                const call = emitToolCall(message);
                if (call.functionCall) return call;
            }

            let newContent = "";

            const delta = choice?.delta;
            const responseContent = delta?.content || dataJson.message?.content;
            const responseReasoning = delta?.reasoning || delta?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                if (!toolCallEmitted && Object.keys(toolCallState).length > 0) {
                    const call = emitToolCall(message);
                    if (call.functionCall) return call;
                }
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }
    
    function onRequestFinished(message) {
        // OpenAI format doesn't need special finish handling
        return {};
    }
    
    function reset() {
        isReasoning = false;
        toolCallState = ({});
        toolCallEmitted = false;
    }

}
