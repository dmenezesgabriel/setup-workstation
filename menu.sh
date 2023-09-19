#!/usr/bin/env bash

submenu() {
    echo -ne "
SUBMENU
1) SUBCMD1
2) Go Back to Main Menu
0) Exit
Choose an option:  "
    read -r ans
    case $ans in
    1)
        sub-submenu
        submenu
        ;;
    2)
        menu
        ;;
    0)
        echo "Bye bye."
        exit 0
        ;;
    *)
        echo "Wrong option."
        exit 1
        ;;
    esac
}

mainmenu() {
    echo -ne "
MAIN MENU
1) CMD1
0) Exit
Choose an option:  "
    read -r ans
    case $ans in
    1)
        submenu
        mainmenu
        ;;
    0)
        echo "Bye bye."
        exit 0
        ;;
    *)
        echo "Wrong option."
        exit 1
        ;;
    esac
}

mainmenu