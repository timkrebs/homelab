<?xml version="1.0" encoding="utf-8"?>
<!--
  Windows 11 Unattended Answer File
  Rendered by Packer's templatefile() — ${winrm_username} and ${winrm_password} are injected at build time.
  Served as a generated CD (label: AUTOUNATTEND) — Windows Setup auto-detects this file on all drives.
-->
<unattend xmlns="urn:schemas-microsoft-com:unattend">

  <!-- ===== WindowsPE pass: disk layout + VirtIO SCSI driver injection ===== -->
  <settings pass="windowsPE">

    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>de-DE</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

      <!--
        TPM/SecureBoot bypass registry keys — belt-and-suspenders safety net.
        The Proxmox VM already has vTPM 2.0 and Secure Boot enabled via the Packer template,
        so these should not be needed, but they prevent a stalled install if the vTPM is not
        yet visible to WinPE during the very first boot.
      -->
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>

      <!--
        VirtIO SCSI driver injection.
        We probe D:–G: because the drive letter for the VirtIO ISO varies depending on the
        number and order of mounted ISOs. Windows Setup silently ignores non-existent paths.
      -->
      <DriverPaths>
        <PathAndCredentials wcm:action="add" wcm:keyValue="D">
          <Path>D:\viostor\w11\amd64</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="E">
          <Path>E:\viostor\w11\amd64</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="F">
          <Path>F:\viostor\w11\amd64</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="G">
          <Path>G:\viostor\w11\amd64</Path>
        </PathAndCredentials>
      </DriverPaths>

      <!-- GPT disk layout required for UEFI boot -->
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add">
              <Order>1</Order>
              <Type>EFI</Type>
              <Size>100</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>2</Order>
              <Type>MSR</Type>
              <Size>16</Size>
            </CreatePartition>
            <CreatePartition wcm:action="add">
              <Order>3</Order>
              <Type>Primary</Type>
              <Extend>true</Extend>
            </CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add">
              <Order>1</Order>
              <PartitionID>1</PartitionID>
              <Label>EFI</Label>
              <Format>FAT32</Format>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
              <Order>2</Order>
              <PartitionID>3</PartitionID>
              <Label>Windows</Label>
              <Letter>C</Letter>
              <Format>NTFS</Format>
            </ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>

      <ImageInstall>
        <OSImage>
          <!--
            Select Windows 11 Pro by image name so Windows Setup does not
            pause to ask which edition to install (the multi-edition ISO
            contains Home, Education, Pro, etc.).  Using the name rather
            than a numeric index is more robust across ISO revisions.
          -->
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>Windows 11 Pro</Value>
            </MetaData>
          </InstallFrom>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
        </OSImage>
      </ImageInstall>

      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>Administrator</FullName>
        <Organization>Homelab</Organization>
        <!--
          Generic/KMS key for Windows 11 Pro — allows fully unattended installation
          without a product key prompt. This key does NOT activate Windows; it only
          selects the Pro edition and suppresses the Setup UI. Activate individual
          clones with a real MAK/retail key after deployment.
        -->
        <ProductKey>
          <Key>W269N-WFGWX-YVC9B-4J6C9-T83GX</Key>
          <WillShowUI>OnError</WillShowUI>
        </ProductKey>
      </UserData>

    </component>
  </settings>

  <!-- ===== specialize pass: hostname, timezone, keyboard ===== -->
  <settings pass="specialize">

    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <ComputerName>win11-template</ComputerName>
      <TimeZone>W. Europe Standard Time</TimeZone>
      <!--
        Disable UAC in specialize (runs as SYSTEM — no elevation dialog).
        Required so that FirstLogonCommands run with full admin rights:
        winrm quickconfig and sc config both fail silently under UAC.
      -->
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 0 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>

    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <InputLocale>de-DE</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

  </settings>

  <!-- ===== oobeSystem pass: user account, autologon, WinRM setup ===== -->
  <settings pass="oobeSystem">

    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

      <!-- Skip all OOBE interactive screens -->
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <NetworkLocation>Work</NetworkLocation>
      </OOBE>

      <!-- Local admin account — credentials injected by Packer at build time -->
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>${winrm_username}</Name>
            <DisplayName>${winrm_username}</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>${winrm_password}</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

      <!-- AutoLogon so FirstLogonCommands run without manual interaction -->
      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>3</LogonCount>
        <Username>${winrm_username}</Username>
        <Password>
          <Value>${winrm_password}</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

      <!--
        Enable WinRM so Packer can connect via the WinRM communicator.
        Runs synchronously before Packer tries to connect.
      -->
      <FirstLogonCommands>
        <!--
          ORDER 1: Install the QEMU guest agent from the VirtIO drivers ISO.
          packer-plugin-proxmox resolves the VM's IP exclusively via the guest agent
          interface data. Without the agent running, Packer never learns the IP and
          WinRM times out after 2 hours regardless of whether WinRM itself is up.
          Scan drive letters D-K; Setup silently skips letters that do not exist.
        -->
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Install QEMU Guest Agent (required for Proxmox IP reporting)</Description>
          <CommandLine>powershell -NoProfile -ExecutionPolicy Bypass -Command "foreach ($d in 'D','E','F','G','H','I','J','K') { $msi = $d + ':\guest-agent\qemu-ga-x86_64.msi'; if (Test-Path $msi) { $a = '/i ' + $msi + ' /qn /norestart'; Start-Process msiexec.exe -ArgumentList $a -Wait -NoNewWindow; break } }"</CommandLine>
        </SynchronousCommand>
        <!--
          ORDER 2: Wait for the guest agent service to start and report the VM's
          IP to the Proxmox API before Packer begins polling for WinRM.
        -->
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Wait for QEMU guest agent to register VM IP with Proxmox</Description>
          <CommandLine>powershell -NoProfile -Command "Start-Sleep -Seconds 30"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Set network profile to Private (required for WinRM)</Description>
          <CommandLine>powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue"</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Description>Quick-configure WinRM with defaults</Description>
          <CommandLine>cmd /c winrm quickconfig -q</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Description>Allow unencrypted WinRM (Packer uses HTTP)</Description>
          <CommandLine>cmd /c winrm set winrm/config/service @{AllowUnencrypted="true"}</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>6</Order>
          <Description>Enable Basic auth for WinRM</Description>
          <CommandLine>cmd /c winrm set winrm/config/service/auth @{Basic="true"}</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>7</Order>
          <Description>Raise WinRM shell memory limit</Description>
          <CommandLine>cmd /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB="512"}</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>8</Order>
          <Description>Open WinRM firewall rule</Description>
          <CommandLine>cmd /c netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>9</Order>
          <Description>Set WinRM service to auto-start</Description>
          <CommandLine>cmd /c sc config winrm start= auto</CommandLine>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>10</Order>
          <Description>Start WinRM service</Description>
          <CommandLine>cmd /c net start winrm</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>

    </component>

    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <InputLocale>de-DE</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>

  </settings>

</unattend>
