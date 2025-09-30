import ExpoModulesCore
import Speech
import AVFoundation

public class PanotSpeechPermissionRequester: NSObject, EXPermissionsRequester {
  static public func permissionType() -> String {
    return "panotSpeech"
  }

  public func requestPermissions(
    resolver resolve: @escaping EXPromiseResolveBlock, rejecter reject: EXPromiseRejectBlock
  ) {
    SFSpeechRecognizer.requestAuthorization { status in
      if status != .authorized {
        resolve(self.getPermissions())
        return
      }
      AVAudioSession.sharedInstance().requestRecordPermission { authorized in
        resolve(self.getPermissions())
      }
    }
  }

  public func getPermissions() -> [AnyHashable: Any] {
    var status: EXPermissionStatus

    let recordPermission = AVAudioSession.sharedInstance().recordPermission
    let speechPermission = SFSpeechRecognizer.authorizationStatus()

    if speechPermission == .authorized && recordPermission == .granted {
      status = EXPermissionStatusGranted
    } else if speechPermission == .denied || recordPermission == .denied
      || speechPermission == .restricted
    {
      status = EXPermissionStatusDenied
    } else {
      status = EXPermissionStatusUndetermined
    }

    return [
      "status": status.rawValue,
      "restricted": speechPermission == .restricted,
    ]
  }
}
