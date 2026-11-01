import Flutter
import LocalAuthentication
import MessageUI
import Security
import UIKit

/// iPhone-Gegenstück zur MainActivity auf Android – gleicher Kanal, gleiche Methoden.
/// Verschickt, wählt oder bezahlt nie selbst: Es öffnet nur die passenden Apps zur Bestätigung.
public class PapiertigerIosPlugin: NSObject, FlutterPlugin, MFMailComposeViewControllerDelegate {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let kanal = FlutterMethodChannel(name: "papiertiger/android", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PapiertigerIosPlugin(), channel: kanal)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "geteilt":
      result([])  // „Teilen an den Papiertiger“ braucht auf dem iPhone eine eigene Erweiterung (später)
    case "oeffnen":
      oeffnen(args["uri"] as? String ?? "", result: result)
    case "mailSenden":
      mailSenden(
        an: args["an"] as? String ?? "",
        betreff: args["betreff"] as? String ?? "",
        text: args["text"] as? String ?? "",
        pfade: args["pfade"] as? [String] ?? [],
        result: result)
    case "appOeffnen":
      // Auf dem iPhone gibt es keinen Paketnamen; die Sparkassen-App öffnest du selbst.
      result(false)
    case "widget":
      result(0)
    case "diktieren":
      result(FlutterError(code: "keine_spracheingabe", message: "Bitte das Mikrofon der Tastatur nutzen", details: nil))
    case "datenschluessel":
      do {
        result(try datenschluessel())
      } catch {
        result(FlutterError(code: "schluessel", message: "\(error)", details: nil))
      }
    case "bildschirmschutz":
      result(true)  // iOS erlaubt kein Sperren von Bildschirmfotos
    case "geraetGesichert":
      var fehler: NSError?
      result(LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &fehler))
    case "geraetEntsperren":
      let ctx = LAContext()
      ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Papiertiger entsperren") { ok, _ in
        DispatchQueue.main.async { result(ok) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Links

  private func oeffnen(_ s: String, result: @escaping FlutterResult) {
    guard let url = URL(string: s) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
  }

  // MARK: E-Mail mit Anhang – abgeschickt wird erst, wenn du in der Mail-Ansicht auf Senden tippst

  private var mailErgebnis: FlutterResult?

  private func mailSenden(an: String, betreff: String, text: String, pfade: [String], result: @escaping FlutterResult) {
    guard MFMailComposeViewController.canSendMail(), let oben = obersterController() else {
      result(false)
      return
    }
    let mail = MFMailComposeViewController()
    mail.mailComposeDelegate = self
    if !an.isEmpty { mail.setToRecipients([an]) }
    mail.setSubject(betreff)
    mail.setMessageBody(text, isHTML: false)
    for p in pfade {
      let url = URL(fileURLWithPath: p)
      guard let daten = try? Data(contentsOf: url) else { continue }
      mail.addAttachmentData(daten, mimeType: mimeTyp(url.pathExtension), fileName: url.lastPathComponent)
    }
    mailErgebnis = result
    oben.present(mail, animated: true)
  }

  public func mailComposeController(
    _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
  ) {
    controller.dismiss(animated: true)
    mailErgebnis?(true)
    mailErgebnis = nil
  }

  private func mimeTyp(_ endung: String) -> String {
    switch endung.lowercased() {
    case "pdf": return "application/pdf"
    case "xml": return "application/xml"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "csv": return "text/csv"
    default: return "application/octet-stream"
    }
  }

  private func obersterController() -> UIViewController? {
    let fenster = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var c = fenster?.rootViewController
    while let p = c?.presentedViewController { c = p }
    return c
  }

  // MARK: Datenschlüssel im Schlüsselbund – nur auf diesem Gerät, nicht in iCloud

  private func datenschluessel() throws -> String {
    let basis: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "de.papiertiger.daten",
      kSecAttrAccount as String: "datenschluessel",
    ]
    var suche = basis
    suche[kSecReturnData as String] = true
    suche[kSecMatchLimit as String] = kSecMatchLimitOne
    var gefunden: CFTypeRef?
    let status = SecItemCopyMatching(suche as CFDictionary, &gefunden)
    if status == errSecSuccess, let daten = gefunden as? Data, daten.count == 32 {
      return daten.base64EncodedString()
    }
    if status != errSecItemNotFound && status != errSecSuccess {
      throw NSError(domain: "Schluesselbund", code: Int(status))
    }
    var neu = Data(count: 32)
    let ok = neu.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
    if ok != errSecSuccess { throw NSError(domain: "Zufall", code: Int(ok)) }
    var eintrag = basis
    eintrag[kSecValueData as String] = neu
    eintrag[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let s = SecItemAdd(eintrag as CFDictionary, nil)
    if s != errSecSuccess { throw NSError(domain: "Schluesselbund", code: Int(s)) }
    return neu.base64EncodedString()
  }
}
