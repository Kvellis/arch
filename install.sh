#!/bin/bash

# 1. Полное форматирование и разметка диска
sgdisk --zap-all /dev/sda

# Создание разделов
parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart ESP fat32 1MiB 513MiB          # EFI-раздел
parted /dev/sda --script set 1 boot on
parted /dev/sda --script mkpart primary linux-swap 513MiB 8585MiB  # swap (8 ГБ)
parted /dev/sda --script mkpart primary ext4 8585MiB 58.5GiB       # Корневой раздел / (50 ГБ)
parted /dev/sda --script mkpart primary ext4 58.5GiB 100%          # Раздел /home

# Форматирование разделов
mkfs.fat -F32 /dev/sda1                   # Форматирование EFI-раздела
mkswap /dev/sda2                          # Форматирование swap-раздела
swapon /dev/sda2                          # Активация swap
mkfs.ext4 /dev/sda3                       # Форматирование корневого раздела /
mkfs.ext4 /dev/sda4                       # Форматирование раздела /home

# Монтирование разделов
mount /dev/sda3 /mnt                      # Монтируем корневой раздел
mkdir -p /mnt/boot/efi                    # Создаем директорию для EFI
mount /dev/sda1 /mnt/boot/efi             # Монтируем EFI-раздел
mkdir /mnt/home                           # Создаем директорию для /home
mount /dev/sda4 /mnt/home                 # Монтируем /home

# 2. Установка базовой системы
pacstrap /mnt base base-devel linux linux-firmware

# 3. Настройка системы
genfstab -U /mnt >> /mnt/etc/fstab        # Генерация fstab

arch-chroot /mnt /bin/bash <<EOF

# Установка часового пояса и локали
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime   # Укажите свой часовой пояс
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Установка переменных окружения для локали
echo "LANG=en_US.UTF-8" > /etc/locale.conf                 # Системный язык — английский
echo "LC_TIME=ru_RU.UTF-8" >> /etc/locale.conf             # Форматы даты и времени — русские
echo "LC_NUMERIC=ru_RU.UTF-8" >> /etc/locale.conf          # Форматы чисел и валюты — русские
echo "LC_MONETARY=ru_RU.UTF-8" >> /etc/locale.conf

# Настройка сети
echo "uwux" > /etc/hostname                          # Укажите имя компьютера
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   myhostname.localdomain myhostname" >> /etc/hosts

# Установка пароля root
echo "Установите пароль для root"
passwd

# Установка загрузчика
pacman -S grub efibootmgr os-prober networkmanager
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager

# Установка KDE Plasma и основных пакетов
pacman -S xorg plasma plasma-wayland-session kde-applications sddm

# Включение SDDM (диспетчера сеансов для KDE)
systemctl enable sddm

# Создание нового пользователя
useradd -m -G wheel -s /bin/bash uwu      # Замените 'user' на нужное имя пользователя
echo "Установите пароль для нового пользователя"
passwd uwu

# Настройка sudo для группы wheel
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

EOF

# 4. Завершение и перезагрузка
umount -R /mnt
swapoff /dev/sda2
echo "Установка завершена. Перезагрузите систему."
