#!/usr/bin/env zsh

# read commandline argument for bash and zsh shell used internally by varoius functions
function readChoice() {
    _choice=$1
    if [[ $SHELL =~ 'bash' ]]; then
        read -r -n 1 $_choice
    else
        read -r -k 1 $_choice
    fi
}

# add user to sudoers
function add_to_sudoers() {
    sudo sed -i '' '$a\
    '"$USER"'        ALL\=\(ALL\) NOPASSWD: ALL' /etc/sudoers
    return $?
}

# set system hostname
function set_system_hostname() {
    echo -ne "[+] please define a hostname name:  \b"
    read -r system_hostname
    echo "[+] Setting ComputerName/LocalHostName/HostName to: '$system_hostname'"
    # set ComputerName/LocalHostName/HostName
    sudo scutil --set ComputerName "$system_hostname"
    sudo scutil --set LocalHostName "$system_hostname"
    sudo scutil --set HostName "$system_hostname"
    return $?
}

# wait for xcode cli tools installation
function wait_for_xcode_cli_tools_installation() {
    choice='n'
    while [[ $choice == 'n' || $choice == 'N' ]]; do
        readChoice choice
        if [[ $choice == 'y' || $choice == 'Y' ]]; then
            echo -ne "\n"
            if [[ -z `xcode-select -p` ]]
                then
                sudo xcode-select --install 2>& 1 > /dev/null
                echo -ne "\nShould we proceed further (y/N):  \b"
                wait_for_xcode_cli_tools_installation
            fi
            break
        else
            sleep 1
        fi
    done
    return $?
}


function run_this_command() {
    _command=$1
    osascript <<EOF
        tell application "Terminal"
            activate window 2
            tell window 2
              set w to do script "$_command && exit"
              repeat
                delay 5
                if not busy of w then exit repeat
              end repeat
             end tell
          close (get window 1)
        end tell
EOF
}

# tweak macOS configuration
function tweak_macOS_configuration() {
    # allow app installation from anywhere
    sudo spctl --master-disable

    # show dock immediately
    defaults write com.apple.dock autohide-delay -float 0

    # Allow side scrollbar only on scrolling
    defaults write com.apple.Terminal AppleShowScrollBars -string WhenScrolling

    # Disable horizontal scrolling for magic mouse
    defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseHorizontalScroll -bool NO

    # remove other from login screen
    sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWOTHERUSERS_MANAGED -bool FALSE

    # enable locate functionality database
    sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist

    # disable prefetchinf DNS links
    defaults write com.apple.safari WebKitDNSPrefetchingEnabled -boolean false

    # Auto play quickTime
    defaults write com.apple.QuickTimePlayerX MGPlayMovieOnOpen 1

    # open text edit by default
    defaults write -g NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

    # set text edit format to plain text by default
    defaults write com.apple.TextEdit RichText 0

    # Disable error reporting dialogue
    defaults write com.apple.CrashReporter DialogType none

    # disable open prompt on app launchs
    defaults write com.apple.LaunchServices LSQuarantine -bool NO

    # restart launchpad and killDock
    defaults write com.apple.dock ResetLaunchPad -bool true
    sudo rm ~/Library/Application\ Support/Dock/*.db
    sudo killall Dock

    # need mac mailer to show attachment as icon always
    defaults write com.apple.mail DisableInlineAttachmentViewing -bool yes

    # make sure postgresapp is in path
    # sudo mkdir -p /etc/paths.d && echo /Applications/Postgres.app/Contents/Versions/latest/bin | sudo tee /etc/paths.d/postgresapp

    # make no sound when a new terminal opens
    touch ~/.hushlogin
}

# install home brew and packages
function install_homebrew() {
    echo -ne "[!] Installing Homebrew\n"
    echo '\r' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

    # disable homebrew analytics
    brew analytics off

    # tap all necessary casks, uncomment as needed
    run_this_command "brew tap homebrew/cask"
    run_this_command "brew tap homebrew/cask-fonts"
    run_this_command "brew tap buo/cask-upgrade"
    # run_this_command "brew tap mongodb/brew"

    # install minimal packages
    # feel free to upgrade cask and tool list to suit your needs
    # install all casks one by one
    while read each_cask; do
        [[ $each_cask =~ ^#.* ]] && echo "[-] Ignoring $each_cask" && continue
        echo -ne "[+] Installing cask $each_cask ${NC}\n"
        run_this_command "brew cask install $each_cask"
    done <packages/commandlineCaskTools.txt

    # install all packages one by one
    while read each_package; do
        [[ $each_package =~ ^#.* ]] && echo "[-] Ignoring $each_package" && continue
        echo -ne "[+] Installing package $each_package ${NC}\n"
        run_this_command "brew install $each_package"
    done <packages/commandlineTools.txt
}

# One time configuration
function main() {

    echo -ne "[+] First thing first, adding user to sudoers file\n"
    add_to_sudoers
    if [[ $? -gt 0 ]]; then
        echo -ne "Did you enter the right password.?\n"
        return 1
    fi

    # set a user defined hostname
    set_system_hostname || exit

    # we need xcode command line tool first
    if [[ -z `xcode-select -p` ]]
    then
        # initially its gonna take a while to install xcode command line tools
        echo -ne "[+] Please allow xcode command line tools to be installed \n"
        sudo xcode-select --install 2>& 1 > /dev/null
        echo -ne "\nShould we proceed further (y/N):  \b"
        wait_for_xcode_cli_tools_installation || exit
    fi

    # tweak system setting, personal preference
    # feel free to comment below line if you dont like them
    tweak_macOS_configuration

    # install homebrew and packages
    install_homebrew

    # install git lfs
    run_this_command "git lfs install"

    # enable nginx as service
    if [[ -e $(which nginx) ]]; then
        brew services start nginx
    fi

    # enable mongo as service
    if [[ -e $(which mongodb) ]]; then
        brew services start mongodb/brew/mongodb-community
    fi

    # update pip and setuptools
    echo -ne "[+] Installing/Updating setuptools${NC}\n"
    run_this_command "/usr/local/bin/pip3 install --upgrade pip setuptools"
    run_this_command "/usr/local/bin/pip3 install virtualenvwrapper"

    # change theme, I like smyck
    mkdir -p ~/.vim/colors && wget -q https://raw.githubusercontent.com/hukl/Smyck-Color-Scheme/master/smyck.vim -O ~/.vim/colors/smyck.vim

    # config fonts for powerline
    mkdir -p ~/.local/share/fonts/
    wget -q https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf -O ~/.local/share/fonts/PowerlineSymbols.otf
    wget -q https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf -O ~/.local/share/fonts/10-powerline-symbols.conf

    # install powerline fonts and cleanup
    run_this_command "git clone https://github.com/powerline/fonts.git --depth=1 && cd fonts && ./install.sh && cd .. && rm -rf fonts"

    # get the meslo font for `p10k configure`
    echo -ne "[+] Get MesloLGS fonts\n"
    meslo_regular="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Regular.ttf"
    meslo_bold="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold.ttf"
    meslo_italic="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Italic.ttf"
    meslo_bold_italic="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold Italic.ttf"

    wget -q "$meslo_regular" -O ~/Library/Fonts/MesloLGS\ NF\ Regular.ttf
    wget -q "$meslo_bold" -O ~/Library/Fonts/MesloLGS\ NF\ Bold.ttf
    wget -q "$meslo_italic" -O ~/Library/Fonts/MesloLGS\ NF\ Italic.ttf
    wget -q "$meslo_bold_italic" -O ~/Library/Fonts/MesloLGS\ NF\ Bold\ Italic.ttf
    run_this_command "fc-cache -vf ~/.local/share/fonts/"

    # one last step
    # set zsh and oh-my-zsh
    run_this_command "brew install zsh zsh-completions"
    run_this_command "rm -f ~/.zcompdump && compinit"
    chmod go-w '/usr/local/share'
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k


    # finally change shell to zsh
    command -v zsh | sudo tee -a /etc/shells
    sudo chsh -s $(command -v zsh)
    chsh -s $(command -v zsh)
    run_this_command "compaudit | xargs chmod g-w,o-w"

    echo "[!] please consider donating me if you can, helps me a meal for the day."
    open -a Safari "https://www.paypal.me/nar3nd3rs1ngh"
    # this script can be tweaked to install pretty much anything from a pkg or DMG file.
}

# lets hit the rock
main
