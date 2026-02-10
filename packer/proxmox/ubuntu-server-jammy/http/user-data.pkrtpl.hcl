#cloud-config
autoinstall:
  version: 1
  locale: en_US
  keyboard:
    layout: de
  ssh:
    install-server: true
    allow-pw: true
    disable_root: true
    ssh_quiet_keygen: true
    allow_public_ssh_keys: true
  packages:
    - qemu-guest-agent
    - openssh-server
    - sudo
  storage:
    layout:
      name: direct
    swap:
      size: 0
  user-data:
    package_upgrade: false
    timezone: Europe/Berlin
    users:
      - name: "${ssh_username}"
        plain_text_passwd: "${ssh_password}"
        groups: [adm, sudo]
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
  late-commands:
    - curtin in-target --target=/target -- systemctl enable qemu-guest-agent
    - curtin in-target --target=/target -- systemctl start qemu-guest-agent
    - curtin in-target --target=/target -- systemctl enable ssh
    - curtin in-target --target=/target -- systemctl start ssh
  shutdown: poweroff
