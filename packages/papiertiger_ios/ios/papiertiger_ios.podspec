Pod::Spec.new do |s|
  s.name             = 'papiertiger_ios'
  s.version          = '1.0.0'
  s.summary          = 'iPhone-Seite des Papiertigers'
  s.description      = 'Schlüsselbund, Face ID, E-Mail mit Anhang, Links öffnen.'
  s.homepage         = 'https://github.com/benderflorian2-a11y/Papiertiger1'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Papiertiger' => 'info@papiertiger.de' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'LocalAuthentication', 'MessageUI', 'Security'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
