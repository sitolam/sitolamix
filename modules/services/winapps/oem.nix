{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.winapps;

  # Office Deployment Tool answer file. `MatchOS` follows the guest's language;
  # the excluded apps are the ones nobody asked for and which slow the install
  # measurably. AUTOACTIVATE is 0 because activation happens through the one
  # interactive Microsoft 365 sign-in, not through a key baked into the config.
  officeConfig = pkgs.writeText "winapps-office-configuration.xml" ''
    <Configuration>
      <Add OfficeClientEdition="64" Channel="Current">
        <Product ID="O365ProPlusRetail">
          <Language ID="MatchOS" />
          <ExcludeApp ID="Groove" />
          <ExcludeApp ID="Lync" />
          <ExcludeApp ID="Bing" />
          <ExcludeApp ID="Teams" />
        </Product>
      </Add>
      <Display Level="None" AcceptEULA="TRUE" />
      <Property Name="AUTOACTIVATE" Value="0" />
      <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    </Configuration>
  '';

  # Runs once, as administrator, at the end of the unattended Windows install.
  # Line endings must be CRLF — cmd.exe mis-parses a LF-only batch file in ways
  # that look like syntax errors in unrelated lines.
  installBat = pkgs.runCommand "winapps-install.bat" { } ''
    ${pkgs.dos2unix}/bin/unix2dos < ${pkgs.writeText "install.bat.lf" ''
      @echo off
      setlocal

      rem ── RDP host + RemoteApp ────────────────────────────────────────────
      rem fDenyTSConnections: accept incoming RDP at all.
      reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

      rem fDisabledAllowList: let an *arbitrary* executable be published as a
      rem RemoteApp. Without this every `winapps <app>` fails, and it fails
      rem looking like a connection problem rather than a permissions one.
      reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList" /v fDisabledAllowList /t REG_DWORD /d 1 /f

      netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

      rem AutoAdminLogon: dockurr/windows' unattended answer file signs the
      rem account in on the emulated console at every boot. Windows 11 client
      rem editions allow exactly one interactive session, so that console
      rem session owns the only slot and every WinApps logon has to take it
      rem over. The server asks the client to confirm that takeover
      rem (LOGON_MSG_BUMP_OPTIONS); FreeRDP has no UI to answer in RemoteApp
      rem mode, so the connection stalls and then dies mid-handover — which
      rem surfaces as "another user is still signed in". Leaving the console
      rem at the sign-in screen makes the RDP session the only session, and
      rem the prompt never happens.
      rem
      rem Only affects a *fresh* install: /oem runs once, at the end of setup.
      rem An already-installed guest needs the same key set by hand — see
      rem docs/design/specs/2026-08-23-winapps-windows-vm-design.md.
      reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f

      rem ── Office 365 ──────────────────────────────────────────────────────
      rem officecdn.microsoft.com/pr/wsus/setup.exe is Microsoft's evergreen
      rem Office Deployment Tool: always current, no version to pin and go
      rem stale. %~dp0 is this script's own directory, i.e. the copied /oem.
      mkdir C:\OfficeSetup
      powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile 'C:\OfficeSetup\setup.exe'"

      if not exist C:\OfficeSetup\setup.exe (
        echo Office Deployment Tool download failed. > C:\OfficeSetup\FAILED.txt
        exit /b 1
      )

      C:\OfficeSetup\setup.exe /configure "%~dp0configuration.xml"
      if errorlevel 1 (
        echo Office install failed, setup.exe exited %errorlevel%. > C:\OfficeSetup\FAILED.txt
        exit /b 1
      )

      endlocal
    ''} > $out
  '';
in
{
  config = lib.mkIf cfg.enable {
    # C+ copies and replaces: the OEM directory is a plain bind mount into the
    # container, and a symlink into /nix/store would not resolve from inside it.
    # Replacing on every activation keeps the host-side copy current with the
    # script above — but dockurr/windows only ever runs /oem once, at the end
    # of the unattended install, so this refreshes what the *next* install will
    # run, not anything on an already-installed guest.
    systemd.tmpfiles.rules = [
      "C+ ${cfg.stateDir}/oem/install.bat 0644 root root - ${installBat}"
      "C+ ${cfg.stateDir}/oem/configuration.xml 0644 root root - ${officeConfig}"
    ];
  };
}
