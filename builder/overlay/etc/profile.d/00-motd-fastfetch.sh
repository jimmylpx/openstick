[ -z "$TERM" ] || [ "$TERM" = "unknown" ] && export TERM=xterm-256color
if [ -t 1 ] && [ -n "$PS1" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch --disk-folders / --logo debian_small 2>/dev/null || fastfetch --disk-folders / 2>/dev/null || true
    fi
    echo ""
    echo -e "\033[1;36m====================================================================\033[0m"
    echo -e "\033[1;33m  💡 HINT: Ketik \033[1;32msbrmenu\033[1;33m untuk mengelola Hotspot, 4G LTE, SMS, dll.\033[0m"
    echo -e "\033[1;33m  🔑 ROOT: Jalankan \033[1;32msudo su\033[1;33m (Password: 1) untuk akses administrator.\033[0m"
    echo -e "\033[1;36m====================================================================\033[0m"
    echo ""
fi
