# Removal and deployment limitations

Master Setup itself is a portable folder application. Close it and all active
installation jobs before deleting its extracted folder. This does not uninstall
Windows, Office or applications installed through it. Remove those applications
using Windows Settings > Apps and the vendors' supported uninstallers.

Windows reinstallation and disk erasure cannot be undone by deleting Master Setup.
Restoring the previous system requires a suitable backup made before deployment.

Do not delete a prepared USB profile, C:\SetupKit, an AtelierPE staging folder or
boot-entry data while a deployment is pending or running. Cancelling preparation
attempts to remove its temporary boot entries, but failures require diagnosis
before manually removing boot-related files. No general automatic rollback is
claimed by this preview.

After deployment has completed, no installation is active and the normal Windows
boot works, retain needed diagnostics, then remove the completed SetupKit and USB
profile if they are no longer needed. Generated answer files may contain account
credentials. Logs are under %LOCALAPPDATA%\AtelierWindows\Journaux,
%PROGRAMDATA%\YHF-Setup and %TEMP%\MasterSetup-startup-*.log. Remove these only after
reviewing whether they are needed for troubleshooting.
