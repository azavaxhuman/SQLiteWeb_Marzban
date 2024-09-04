#!/bin/bash

# DDS : DailyDigtalSKiills
# YOUTUBE LINK: https://www.youtube.com/@DailyDigtalSKills
#Telegram: @DailyDigtalSKiills

# Colors for better readability
colors=(
    "\033[38;2;255;105;180m"  # Foreground (#EA549F)
    "\033[38;2;255;20;147m"   # Red (#E92888)
    "\033[38;2;0;255;144m"    # Green (#4EC9B0)
    "\033[38;2;0;191;255m"    # Blue (#579BD5)
    "\033[38;2;102;204;255m"  # Bright Blue (#9CDCFE)
    "\033[38;2;242;242;242m"  # Bright White (#EAEAEA)
    "\033[38;2;0;255;255m"    # Cyan (#00B6D6)
    "\033[38;2;255;215;0m"    # Bright Yellow (#e9ad95)
    "\033[38;2;160;32;240m"   # Purple (#714896)
    "\033[38;2;255;36;99m"    # Bright Red (#EB2A88)
    "\033[38;2;0;255;100m"    # Bright Green (#1AD69C)
    "\033[38;2;0;255;255m"    # Bright Cyan (#2BC4E2)
    "\033[0m"                 # Reset
)
foreground=${colors[0]} red=${colors[1]} green=${colors[2]} blue=${colors[3]} brightBlue=${colors[4]} brightWhite=${colors[5]} cyan=${colors[6]} brightYellow=${colors[7]} purple=${colors[8]} brightRed=${colors[9]} brightGreen=${colors[10]} brightCyan=${colors[11]} reset=${colors[12]}

# Helper functions
print() { echo -e "${cyan}$1${reset}"; }
error() { echo -e "${red}✗ $1${reset}"; }
success() { echo -e "${green}✓ $1${reset}"; }
log() { echo -e "${blue}! $1${reset}"; }
input() { read -p "$(echo -e "${brightYellow}▶ $1${reset}")" "$2"; }
confirm() { read -p "$(echo -e "\n${purple}Press any key to continue...${reset}")"; }

check_success() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$2"
        exit 1
    fi
}

# Function to display the main menu
show_menu() {
    log "SQLite Web Service Manager"
    print ""
    print "1) Install Service"
    print "2) Manage Service"
    print "3) Uninstall Service"
    print "0) Exit"
    print ""
    input "Please choose an option: " choice
}

# Function to display the management submenu
show_manage_menu() {
    clear
    log "Manage SQLite-Web Service"
    print ""
    print "0) Show Full Log"
    print "1) Stop Service"
    print "2) Restart Service"
    print "3) Change URL Path"
    print "4) Change Port"
    print "5) Change Password"
    print "6) Change SQLite File Path"
    print "7) Change SSL Certificate"
    print "8) Back to Main Menu"
    input "Please choose an option: " manage_choice
}

# Function to install the service
install_service() {
    log "Updating and upgrading the system...(Please wait)"
    sudo apt update -y > /dev/null 2>&1  
    sudo apt upgrade -y > /dev/null 2>&1
    check_success "System updated" "Failed to update system"

    log "Installing required packages...(Please wait)"
    sudo apt install -y sqlite3 python3 python3-pip > /dev/null 2>&1
    pip install sqlite-web > /dev/null 2>&1
    check_success "Required packages installed" "Failed to install required packages"

    DEFAULT_SQLITE_FILE="/var/lib/marzban/db.sqlite3"
    while true; do
        input "Please enter the path to the SQLite file (e.g., $DEFAULT_SQLITE_FILE): " SQLITE_FILE
        if [$SQLITE_FILE == ""]; then
            SQLITE_FILE=$DEFAULT_SQLITE_FILE
            success "Using default SQLite file: $SQLITE_FILE"
        fi

        if [ -f "$SQLITE_FILE" ]; then
            break
        else
            error "The specified SQLite file does not exist. Please try again."
        fi
    done

    backup_sqlite_file "$SQLITE_FILE"

    #Input Port check it is not already in use and is a valid port number
    DEFAULT_PORT=8010;
    while true; do
        input "Please enter the port for the web interface (e.g., $DEFAULT_PORT): " PORT
        if [$PORT == ""]; then
            PORT=$DEFAULT_PORT
            success "Using default port: $PORT"
        fi

        if ! [[ $PORT =~ ^[0-9]+$ ]] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
            error "Invalid port number. Please try again."
        elif lsof -i :$PORT | grep -q LISTEN; then
            error "Port $PORT is already in use. Please try again."
        else
            break
        fi
    done
    while true; do
        input "Please enter the Password for accessing the web interface: " PASSWORD
            if [ "$PASSWORD" == "" ]; then
                error "Password cannot be empty. Please try again."
                continue
            fi
    break
    done
    input "Do you want to create a random URL path? (y/n): " random_path_choice
    if [ "$random_path_choice" == "y" ]; then
        URL_PATH=$(openssl rand -hex 12)
    else
        input "Please enter a custom URL path (e.g., /sqlite-web): " URL_PATH
    fi
ssl_choice=""
while true; do
    input "Do you want to enable SSL (HTTPS)? (y / n): " ssl_choice
    if [ "$ssl_choice" == "" || "$ssl_choice" == "y" ]; then
        input "Please enter the domain name for the SSL certificate (e.g., example.com): " domain
        input "Please enter the path to the SSL certificate ( e.g /etc/ssl/certs/example.crt ): " SSL_CERT
        input "Please enter the path to the SSL private key ( e.g /etc/ssl/private/example.key ): " SSL_KEY

        if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
            error "The SSL certificate or key file does not exist at the specified paths."
            continue
        fi

        SSL_OPTIONS="-c $SSL_CERT -k $SSL_KEY"
        break
    else
        SSL_OPTIONS=""
        break
    fi
done

    USER=$(whoami)
    SERVICE_FILE="/etc/systemd/system/sqlite-web.service"
    log "Creating systemd service at $SERVICE_FILE..."
    unset SQLITE_WEB_PASSWORD

    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=sqlite-web service
After=network.target

[Service]
Environment="SQLITE_WEB_PASSWORD=$PASSWORD"
ExecStart=/usr/local/bin/sqlite_web -H 0.0.0.0 -p $PORT -u /$URL_PATH -P $SSL_OPTIONS $SQLITE_FILE
Restart=always
User=$USER
WorkingDirectory=$(dirname $SQLITE_FILE)

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable sqlite-web
    sudo systemctl start sqlite-web
    if [ $? -eq 0 ]; then

        success "The sqlite-web service has been created and started."
                if [ "$ssl_choice" == "y" ]; then
                    success "To access the service over HTTPS, use the following URL: https://$domain:$PORT/$URL_PATH"
                else
                    success "To access the service over HTTP, use the following URL: http://$(curl -4 -s ifconfig.me):$PORT/$URL_PATH"
                fi
                print ""
                success " Your password is: $PASSWORD [Please don't forget it & keep it safe]"
        confirm "Press any key to continue..."
    else
        error "Failed to start the sqlite-web service."
    fi



}

# Function to manage the service
manage_service() {
    if [ ! -f "/etc/systemd/system/sqlite-web.service" ]; then  
        error "The sqlite-web service is not installed. Please install the service first."
        confirm "Press any key to continue..."
        break
    else
    while true; do
        show_manage_menu
        case $manage_choice in
            0) sudo journalctl -u sqlite-web --no-pager  ;;
            1) sudo systemctl stop sqlite-web; success "Service stopped."     ;;
            2) sudo systemctl restart sqlite-web; success "Service restarted."  ;;
            3) change_url_path ;;
            4) change_port ;;
            5) change_password ;;
            6) change_sqlite_path ;;
            7) change_ssl_cert ;;
            8) break;;
            *) error "Invalid option. Please try again." ;;
        esac
        confirm "Press any key to continue..." 
    done

    fi

}

# Function to change the service port
change_port() {
    input "Please enter the new port: " PORT
    sudo sed -i "s/-p [0-9]*/-p $PORT/" /etc/systemd/system/sqlite-web.service
    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl restart sqlite-web > /dev/null 2>&1
    check_success "Port changed to $PORT and service restarted." "Failed to change port."
}

# Function to change the service password
change_password() {
    input "Please enter the new password: " PASSWORD
    sudo sed -i "s/Environment=\"SQLITE_WEB_PASSWORD=.*/Environment=\"SQLITE_WEB_PASSWORD=$PASSWORD\"/" /etc/systemd/system/sqlite-web.service
    sudo systemctl daemon-reload
    sudo systemctl restart sqlite-web
    check_success "Password changed and service restarted." "Failed to change password."
}

# Function to change the SQLite file path
change_sqlite_path() {
    input "Please enter the new path to the SQLite file: " SQLITE_FILE
    sudo sed -i "s| -P .*| -P $SQLITE_FILE|" /etc/systemd/system/sqlite-web.service
    sudo systemctl daemon-reload
    sudo systemctl restart sqlite-web
    check_success "SQLite file path changed to $SQLITE_FILE and service restarted." "Failed to change SQLite file path."
}

# Function to change the URL path
change_url_path() {
    input "Please enter the new URL path: " URL_PATH
    sudo sed -i "s| -u .*| -u /$URL_PATH|" /etc/systemd/system/sqlite-web.service
    sudo systemctl daemon-reload
    sudo systemctl restart sqlite-web
    check_success "URL path changed to /$URL_PATH and service restarted." "Failed to change URL path."
}

# Function to change the SSL certificate
change_ssl_cert() {
    input "Please enter the path to the new SSL certificate (.crt file): " SSL_CERT
    input "Please enter the path to the new SSL private key (.key file): " SSL_KEY

    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        error "The SSL certificate or key file does not exist at the specified paths."
        return 1
    fi

    sudo sed -i "s|-c .* -k .*|-c $SSL_CERT -k $SSL_KEY|" /etc/systemd/system/sqlite-web.service
    sudo systemctl daemon-reload
    sudo systemctl restart sqlite-web
    check_success "SSL certificate changed and service restarted." "Failed to change SSL certificate."
}

# Function to backup the SQLite file
backup_sqlite_file() {
    local file_path=$1
    local backup_path="${file_path}.$(date +%F_%T).bak"
    cp "$file_path" "$backup_path"
    check_success "Backup of SQLite file created at $backup_path" "Failed to create backup of SQLite file"
}

# Function to uninstall the service
uninstall_service() {
    log "Uninstalling sqlite-web service..."
    log "Stopping and disabling service..."
    sudo systemctl stop sqlite-web
    check_success "Service stopped." "Failed to stop service."
    log "disabling service..."
    sudo systemctl disable sqlite-web
    check_success "Service disabled." "Failed to disable service."
    log "removing service file..."
    sudo rm -f /etc/systemd/system/sqlite-web.service
    check_success "Service file removed." "Failed to remove service file."
    log "reloading systemd..."
    sudo systemctl daemon-reload
    check_success "sqlite-web service uninstalled." "Failed to uninstall sqlite-web service."
    confirm "Press any key to continue..."
}



clear
# Main script logic
while true; do
        print ""
        print "           Welcome to the SQLite3-Web + MARZBAN setup script."
        log " ______________________________________________________________"
        print " "         
        success "           @DailyDigtalSKiills  |  GITHUB :@azavaxhuman"
        print " "
    show_menu
    case $choice in
        1) install_service ;;
        2) manage_service ;;
        3) uninstall_service ;;
        0) exit 0 ;;
        *) error "Invalid option. Please try again." 
        confirm "Press any key to continue..."
        ;;
        
    esac
    clear
done
