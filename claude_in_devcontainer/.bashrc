# ~/.bashrc: executed by bash(1) for non-login shells.
# Blended Configuration for Mosgarage & DevOps on WSL

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac
# Mosgarage Workspace Manager Alias
alias wsm='python3 /c/Users/igewe/.mosgarage-wsm/workspace-manager.py'
WINDOWS_USERNAME="igewebs"

export PATH="$PATH:/mnt/c/Windows/System32:/mnt/c/Users/igewe/AppData/Local/Programs/Microsoft VS Code/bin"
# or...
# export PATH="$PATH:/mnt/c/Program Files/Microsoft VS Code/bin"
# or...
# export PATH="$PATH:/mnt/c/Program Files (x86)/Microsoft VS Code/bin"
# --- 1. History Settings ---
# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
# append to the history file, don't overwrite it
shopt -s histappend
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000
# check the window size after each command and, if necessary, update LINES/COLUMNS.
shopt -s checkwinsize

# --- 2. Color Support & LS Aliases ---
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# --- 3. Dynamic Prompt (User Specific) ---
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" == "devops" ]; then
    # Red prompt for DevOps
    PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
elif [ "$CURRENT_USER" == "mosgarage" ]; then
    # Green prompt for Mosgarage
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    # Default fallback
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

# Set terminal title
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# --- 4. Powerful Aliases ---
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove && sudo apt clean'

# Git Shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'

# VS Code Insiders
alias code='code-insiders'
alias vscode='code-insiders .'

# Alert alias for long running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Source global aliases if they exist
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# --- 5. SSH Agent Configuration (Blended Logic) ---

# STRATEGY A: Try to use Windows SSH Agent first (Best for cross-OS key sharing)
# In modern WSL2, the Windows agent is often exposed here.
if [ -S "/run/WSL/ssh-agent.sock" ]; then
    export SSH_AUTH_SOCK="/run/WSL/ssh-agent.sock"
    # Optional: Print confirmation only once per session if desired
    # echo "🔑 Using Windows SSH Agent."
else
    # STRATEGY B: Fallback to your existing persistent Linux Agent logic
    # Check if there is already an ssh-agent AUTH_SOCK configured in the environment
    if [ "$SSH_AUTH_SOCK" = "" ]; then
        SSH_AGENT_OUTPUT=$(cat ~/.ssh-agent-output 2>/dev/null)

        # Check if an ssh-agent command's output has already been saved
        if [ "$SSH_AGENT_OUTPUT" = "" ]; then
            # If not : run a new agent
            SSH_AGENT_OUTPUT=$(ssh-agent)
            echo "$SSH_AGENT_OUTPUT" > ~/.ssh-agent-output
        fi

        # Populate environment with ssh-agent's output
        eval "$SSH_AGENT_OUTPUT"
    fi

    # Check if what's been saved matches current processes
    # Note: Uses pgrep as per your original config
    SSH_CURRENT_AGENT_PID=$(pgrep ssh-agent)

    # Extract PID from the saved output variable for comparison
    SAVED_PID=$(echo "$SSH_AGENT_OUTPUT" | sed -n 's/.*SSH_AGENT_PID=\([0-9]*\).*/\1/p')

    if [ "$SAVED_PID" != "$SSH_CURRENT_AGENT_PID" ] || [ -z "$SSH_CURRENT_AGENT_PID" ]; then
        # If not (e.g., after a restart): launch a new ssh-agent
        SSH_AGENT_OUTPUT=$(ssh-agent)
        echo "$SSH_AGENT_OUTPUT" > ~/.ssh-agent-output
        eval "$SSH_AGENT_OUTPUT"
        echo "🔄 SSH Agent restarted (PID: $SSH_CURRENT_AGENT_PID)"
    fi
fi

# Helper to easily add keys from Windows path
alias ssh-add-win='ssh-add /mnt/c/Users/igewe/.ssh/devpod'

# --- 6. Programmable Completion ---
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# --- 7. Auto-Start Logic (Uncomment to Enable) ---
if [[ $- == *i* ]]; then
    # Example: Auto-open VS Code Insiders in current directory upon login
    # Uncomment the line below if you want this behavior every time:
    code-insiders . &

    # Example: DevOps Specific Startup Tasks
    if [ "$CURRENT_USER" == "devops" ]; then
        echo "🚀 DevOps Environment Loaded."
        # Example: Ensure a service is running (placeholder)
        # pgrep -x "node" > /dev/null || (nohup node /home/devops/service/app.js > /tmp/svc.log 2>&1 &)
    fi

    echo "Welcome, $CURRENT_USER!"
fi
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code-insiders --locate-shell-integration-path bash)"
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk "{print $2}"):0
export LIBGL_ALWAYS_INDIRECT=1
