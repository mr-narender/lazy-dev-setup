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
    "$USER"        ALL\=\(ALL\) NOPASSWD: ALL' /etc/sudoers
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
    sudo xcode-select --install
    echo -ne "\nShould we proceed further (y/N):  \b"
    while [[ $choice == 'n' || $choice == 'N' ]]; do
        if [[ "$(sudo xcode-select --install 2>&1)" != "xcode-select: error: command line tools are already installed, use \"Software Update\" to install updates" ]]; then
            wait_for_xcode_cli_tools_installation
        fi
        readChoice choice
        if [[ $choice == 'y' || $choice == 'Y' ]]; then
            echo -ne "\n"
            break
        else
            sleep 1
        fi
    done
    return $?
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
    brew tap homebrew/cask
    brew tap homebrew/cask-fonts
    brew tap buo/cask-upgrade
    # brew tap mongodb/brew

    # install minimal packages
    # feel free to upgrade it to suit your need
    declare commandlineCaskTools=(
        java \ # java installation, if you need java runtime environemtn
        iterm2 \ # I prefer iterm against Apple Terminal.app
        adguard \ # block ads \(they are good\)
        kap \ # little recording tool
        spectacle \ # Move and resize windows with ease
        appcleaner \ # easy app cleanup
        visual-studio-code \ # I'm sure you this, :P
        kite \ # Kite is the AI assistant giving developers superpowers.
        keepingyouawake \ # Caffeine for mac
        dozer \ # hide icon from tray
        the-unarchiver \ # The Unarchiver is the only app you need to open RAR on Mac
        skype \ # skype for 
        macs-fan-control \ # Macs Fan Control
        nightowl \ # Easily toggle macos Mojaves dark mode
        firefox \ # firefox for macOS
        font-hack-nerd-font font-fira-code \ # fonts
        android-platform-tools \ # android adb and fastboot tools
        mos \ # easy mouse scroll
        barrier \ # KVM switch for multiplse OS 
        google-chrome \ # google chrome for macOS
        postgres \ # postgresql for macOS
        # feel free to add more toold if need to
    )

    # install all casks one by one
    for each in ${commandlineCaskTools[*]}; do
        echo -ne "${GREEN}Installing cask $each ${NC}\n"
        brew cask install $each
    done

    declare commandlineTools=(
        pkg-config \ # Manage compile and link flags for libraries
        aria2  \ # Download with resuming and segmented downloading
        gnutls  \ # GNU Transport Layer Security (TLS) Library
        readline  \ # Library for command-line editing
        coreutils \ # GNU File, Shell, and Text utilities
        openssl \ # Cryptography and SSL/TLS Toolkit
        ssh-copy-id \ # Add a public key to a remote machine's authorized_keys file
        wget \ # Internet file retriever
        python3 \ # Interpreted, interactive, object-oriented programming language
        git \ # Distributed revision control system
        git-lfs \ # Git extension for versioning large files
        fontconfig \ # XML-based font configuration API for X Windows
        ruby \ # Powerful, clean, object-oriented scripting language
        node \ # Platform built on V8 to build network applications
        ffmpeg \ # Play, record, convert, and stream audio and video
        x264 \ # H.264/AVC encoder
        xvid \ # High-performance, high-quality MPEG-4 video library
        yarn \ # JavaScript package manager
        webpack \ # Bundler for JavaScript and friends
        handbrake # Open-source video transcoder available for Linux, Mac, and Windows
        nginx \ # HTTP\(S\) server and reverse proxy, and IMAP/POP3 proxy server
        # mongodb \ # mongo database
    )

    for each in ${commandlineTools[*]}; do
        brew install $each
    done
}

# One time configuration
function main() {

    echo -ne "[+] First thing first, adding user to sudoers file\n"
    if [[ add_to_sudoers -gt 0 ]]; then
        echo -ne "Did you enter the right password.?\n"
        return 1
    fi

    # set a user defined hostname
    set_system_hostname || exit

    # we need xcode command line tool first
    echo -ne "[+] please allow to install xcode command line tools to be installed from user interface popup\n"
    # initially its gonna take a while to install xcode command line tools
    wait_for_xcode_cli_tools_installation || exit

    # tweak system setting, personal preference
    # feel free to comment below line if you dont like them
    tweak_macOS_configuration

    # install homebrew and packages
    install_homebrew

    # install git lfs
    git lfs install

    # enable nginx as service
    if [[ -e $(which nginx) ]]; then
        brew services start nginx
    fi

    # enable mongo as service
    if [[ -e $(which mongodb) ]]; then
        brew services start mongodb/brew/mongodb-community
    fi

    # update pip and setuptools
    echo -ne "${GREEN}[!] Installing/Updating setuptools${NC}\n"
    /usr/local/bin/pip3 install --upgrade pip setuptools
    /usr/local/bin/pip3 install virtualenvwrapper

    # change theme, I like smyck
    mkdir -p ~/.vim/colors && wget -q https://raw.githubusercontent.com/hukl/Smyck-Color-Scheme/master/smyck.vim -O ~/.vim/colors/smyck.vim

    # config fonts for powerline
    mkdir -p ~/.local/share/fonts/
    wget -q https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf -O ~/.local/share/fonts/PowerlineSymbols.otf
    wget -q https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf -O ~/.local/share/fonts/10-powerline-symbols.conf
    fc-cache -vf ~/.local/share/fonts/

    # install powerline fonts and cleanup
    git clone https://github.com/powerline/fonts.git --depth=1 && cd fonts && ./install.sh && cd .. && rm -rf fonts

    # get the meslo font for `p10k configure`
    echo -ne "${GREEN}[!] Get MesloLGS fonts\n"
    meslo_regular="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Regular.ttf"
    meslo_bold="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold.ttf"
    meslo_italic="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Italic.ttf"
    meslo_bold_italic="https://github.com/romkatv/dotfiles-public/raw/master/.local/share/fonts/NerdFonts/MesloLGS NF Bold Italic.ttf"

    wget -q "$meslo_regular" -O ~/Library/Fonts/MesloLGS\ NF\ Regular.ttf
    wget -q "$meslo_bold" -O ~/Library/Fonts/MesloLGS\ NF\ Bold.ttf
    wget -q "$meslo_italic" -O ~/Library/Fonts/MesloLGS\ NF\ Italic.ttf
    wget -q "$meslo_bold_italic" -O ~/Library/Fonts/MesloLGS\ NF\ Bold\ Italic.ttf

    # one last step
    # set zsh and oh-my-zsh
    brew install zsh zsh-completions
    rm -f ~/.zcompdump
    compinit
    chmod go-w '/usr/local/share'
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    git clone https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/themes/powerlevel10k

    # finally change shell to zsh
    command -v zsh | sudo tee -a /etc/shells
    sudo chsh -s $(command -v zsh)
    chsh -s $(command -v zsh)
    osascript -e 'tell application "Terminal" to do script "compaudit | xargs chmod g-w,o-w"'

    # this script can be tweaked to install pretty much anything from a pkg or DMG file.
}

# lets hit the rock
main
