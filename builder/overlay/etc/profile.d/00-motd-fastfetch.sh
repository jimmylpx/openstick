[ -z "$TERM" ] || [ "$TERM" = "unknown" ] && export TERM=xterm-256color
if [ -t 1 ] && [ -n "$PS1" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch --disk-folders / --logo debian_small 2>/dev/null || fastfetch --disk-folders / 2>/dev/null || true
    fi
    echo ""
    echo -e "[1;36m====================================================================[0m"
    echo -e "[1;32m  🚀 Debian 12 Bookworm (Modem-Disabled Edition)[0m"
    echo -e "[1;33m  💡 HINT: Ketik [1;32msbrmenu[1;33m untuk mengelola Wi-Fi, Hotspot, USB Mode, dll.[0m"
    echo -e "[1;33m  🔑 ROOT: Jalankan [1;32msudo su[1;33m (Password: 1) untuk akses administrator.[0m"
    echo -e "[1;36m====================================================================[0m"
    echo ""
fi
