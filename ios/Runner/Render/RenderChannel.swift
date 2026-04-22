import Flutter
import Foundation

enum RenderChannel {
    static let name = "com.uscut/render"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "renderAlternating":
                handleRender(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func handleRender(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments else {
            result(RenderError.invalidRequest(field: "arguments").toFlutterError())
            return
        }

        let request: RenderRequest
        do {
            request = try RenderRequest.decode(from: args)
        } catch let err as RenderError {
            result(err.toFlutterError())
            return
        } catch {
            result(FlutterError(
                code: "INVALID_REQUEST",
                message: error.localizedDescription,
                details: nil
            ))
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                let success = try await RenderEngine.render(request: request)
                await MainActor.run {
                    result(success.toDictionary())
                }
            } catch let err as RenderError {
                await MainActor.run {
                    result(err.toFlutterError())
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "EXPORT_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}
