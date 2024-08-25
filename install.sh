#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# Function to display the main menu
show_menu() {
  
  echo -e "${GREEN}SQLite Web Service Manager${NC}"
  echo -e "${YELLOW}1) Install Service${NC}"
  echo -e "${YELLOW}2) Manage Service${NC}"
  echo -e "${YELLOW}3) Uninstall Service${NC}"
  echo -e "${YELLOW}4) Exit${NC}"
  echo -n "Please choose an option: "
}

# Function to display the management submenu
show_manage_menu() {
  echo -e "${GREEN}Manage SQLite Web Service${NC}"
  echo -e "${YELLOW}0) Show Full Log${NC}"
  echo -e "${YELLOW}1) Stop Service${NC}"
  echo -e "${YELLOW}2) Restart Service${NC}"
  echo -e "${YELLOW}3) Change URL Path${NC}"
  echo -e "${YELLOW}4) Change Port${NC}"
  echo -e "${YELLOW}5) Change Password${NC}"
  echo -e "${YELLOW}6) Change SQLite File Path${NC}"
  echo -e "${YELLOW}7) Change SSL Certificate${NC}"
  echo -e "${YELLOW}8) Back to Main Menu${NC}"
  echo -n "Please choose an option: "
}

# Function to install the service
install_service() {
  # Update and upgrade the system
  echo -e "${BLUE}Updating and upgrading the system...${NC}"
  sudo apt update && sudo apt upgrade -y

  # Install required packages
  echo -e "${BLUE}Installing required packages...${NC}"
  sudo apt install -y sqlite3 python3 python3-pip
  pip install sqlite-web

  # Prompt user for SQLite file path
# Default SQLite file path
DEFAULT_SQLITE_FILE="/var/lib/marzban/db.sqlite3"

# Prompt user for SQLite file path with default value
read -p "Please enter the path to the SQLite file [Default: $DEFAULT_SQLITE_FILE]: " SQLITE_FILE

# Use the default path if the user input is empty
SQLITE_FILE=${SQLITE_FILE:-$DEFAULT_SQLITE_FILE}

# Check if the SQLite file exists
if [ ! -f "$SQLITE_FILE" ]; then
  echo -e "${RED}Error: The SQLite file does not exist at the specified path.${NC}"
  return 1
fi

  # Create a backup of the SQLite file
backup_sqlite_file "$SQLITE_FILE"

  # Prompt user for port number
  read -p "Please enter the port to run the server on (e.g., 8080): " PORT

  # Prompt user for password (hidden input)
  read -sp "Please enter the password for accessing the web interface: " PASSWORD
  echo

  # Create random URL path if -u option is provided
  read -p "Do you want to create a random URL path? (y/n): " random_path_choice
  if [ "$random_path_choice" == "y" ]; then
    URL_PATH=$(openssl rand -hex 12)
  else
    read -p "Please enter a custom URL path (e.g., /sqlite-web): " URL_PATH
  fi

  # Prompt user if they want to configure SSL
read -p "Do you want to configure SSL? (y/n)[Default: y]: " ssl_choice
if [[ "$ssl_choice" == "y" ]] || [[ "$ssl_choice" == "Y" ]] || [[ "$ssl_choice" == "yes" ]] || [[ "$ssl_choice" == "Yes" ]] || [[ "$ssl_choice" == "" ]]; then
    read -p "Please enter Domain/Subdomain (e.g., example.com): " domain
    read -p "Please enter the path to the SSL public key (.crt file): " SSL_CERT
    read -p "Please enter the path to the SSL private key (.key file): " SSL_KEY

    # Validate SSL paths
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        echo -e "${RED}Error: The SSL certificate or key file does not exist at the specified paths.${NC}"
        return 1
    fi

    SSL_OPTIONS="-c $SSL_CERT -k $SSL_KEY"
else
    SSL_OPTIONS=""
fi


  # Get the username of the current user
  USER=$(whoami)

  # Create the systemd service file
  SERVICE_FILE="/etc/systemd/system/sqlite-web.service"
  echo -e "${BLUE}Creating systemd service at $SERVICE_FILE...${NC}"
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

  # Reload systemd, enable, and start the service
  sudo systemctl daemon-reload
  sudo systemctl enable sqlite-web
  sudo systemctl start sqlite-web

  echo -e "${GREEN}The sqlite-web service has been created and started.${NC}"
  #https if ssl_choice is y

  if [ "$ssl_choice" == "y" ]; then
    echo -e "${GREEN}To access the service over HTTPS, use the following URL: ${BLUE}https://$domain:$PORT/$URL_PATH${NC}"
  else
    echo -e "${GREEN}To access the service over HTTP, use the following URL: ${BLUE}http://$(curl -4 -s ifconfig.me):$PORT/$URL_PATH${NC}"
  fi
}

# Function to manage the service
manage_service() {
  while true; do
    show_manage_menu
    read -r manage_choice
    case $manage_choice in
      0) sudo journalctl -u sqlite-web --no-pager ;;
      1) sudo systemctl stop sqlite-web; echo -e "${GREEN}Service stopped.${NC}" ;;
      2) sudo systemctl restart sqlite-web; echo -e "${GREEN}Service restarted.${NC}" ;;
      3) change_url_path ;;
      4) change_port ;;
      5) change_password ;;
      6) change_sqlite_path ;;
      7) change_ssl_cert ;;
      8) break ;;
      *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
    esac
  done
}

# Function to change the service port
change_port() {
  unset PORT
  read -p "Please enter the new port: " PORT
  sudo sed -i "s/-p [0-9]*/-p $PORT/" /etc/systemd/system/sqlite-web.service
  sudo systemctl daemon-reload
  sudo systemctl restart sqlite-web
  echo -e "${GREEN}Port changed to $PORT and service restarted.${NC}"
}

# Function to change the service password
change_password() {
  unset SQLITE_WEB_PASSWORD
  read -sp "Please enter the new password: " PASSWORD
  echo
  sudo sed -i "s/Environment=\"SQLITE_WEB_PASSWORD=.*/Environment=\"SQLITE_WEB_PASSWORD=$PASSWORD\"/" /etc/systemd/system/sqlite-web.service
  sudo systemctl daemon-reload
  sudo systemctl restart sqlite-web
  echo -e "${GREEN}Password changed and service restarted.${NC}"
}

# Function to change the SQLite file path
change_sqlite_path() {
  unset SQLITE_FILE
  read -p "Please enter the new path to the SQLite file: " SQLITE_FILE
  sudo sed -i "s| -P .*| -P $SQLITE_FILE|" /etc/systemd/system/sqlite-web.service
  sudo systemctl daemon-reload
  sudo systemctl restart sqlite-web
  echo -e "${GREEN}SQLite file path changed to $SQLITE_FILE and service restarted.${NC}"
}

# Function to change the URL path
change_url_path() {
  unset URL_PATH
  read -p "Please enter the new URL path: " URL_PATH
  sudo sed -i "s| -u .*| -u /$URL_PATH|" /etc/systemd/system/sqlite-web.service
  sudo systemctl daemon-reload
  sudo systemctl restart sqlite-web
  echo -e "${GREEN}URL path changed to /$URL_PATH and service restarted.${NC}"
}
change_ssl_cert() {
  unset SSL_CERT SSL_KEY
  read -p "Please enter the new path to the SSL public key (.crt file): " SSL_CERT
  read -p "Please enter the new path to the SSL private key (.key file): " SSL_KEY

  # Validate SSL paths
  if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
    echo -e "${RED}Error: The SSL certificate or key file does not exist at the specified paths.${NC}"
    return 1
  fi

  # Check if SSL options already exist in the service file
  if sudo grep -q ' -c ' /etc/systemd/system/sqlite-web.service; then
    # If SSL options exist, replace them
    sudo sed -i "s| -c .* -k .*| -c $SSL_CERT -k $SSL_KEY|" /etc/systemd/system/sqlite-web.service
  else
    # If SSL options do not exist, add them before the database path
    sudo sed -i "s|ExecStart=/usr/local/bin/sqlite_web|ExecStart=/usr/local/bin/sqlite_web -c $SSL_CERT -k $SSL_KEY|" /etc/systemd/system/sqlite-web.service
  fi

  # Reload systemd, restart the service
  sudo systemctl daemon-reload
  sudo systemctl restart sqlite-web

  echo -e "${GREEN}SSL certificate and key changed and service restarted.${NC}"
}


# Function to create a backup of the given SQLite file
backup_sqlite_file() {
  # Get the path to the SQLite file from the function parameter
  local SQLITE_FILE="$1"

  # Check if the file exists
  if [ ! -f "$SQLITE_FILE" ]; then
    echo -e "${RED}Error: The SQLite file does not exist at the specified path.${NC}"
    return 1
  fi

  # Get the current time in the format YYYYMMDD-HHMMSS
  local TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

  # Extract directory and filename from the original SQLite file path
  local SQLITE_DIR=$(dirname "$SQLITE_FILE")
  local SQLITE_BASENAME=$(basename "$SQLITE_FILE")

  # Create the backup filename
  local BACKUP_FILE="$SQLITE_DIR/${SQLITE_BASENAME%.sqlite3}-backup-$TIMESTAMP.sqlite3"

  # Copy the original SQLite file to create a backup
  cp "$SQLITE_FILE" "$BACKUP_FILE"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Backup created successfully: ${BACKUP_FILE}${NC}"
  else
    echo -e "${RED}Error: Failed to create the backup.${NC}"
  fi
}


# Function to uninstall the service
uninstall_service() {
  echo -e "${RED}Stopping and disabling the sqlite-web service...${NC}"
  sudo systemctl stop sqlite-web
  sudo systemctl disable sqlite-web

  echo -e "${RED}Removing the service file...${NC}"
  sudo rm /etc/systemd/system/sqlite-web.service

  echo -e "${RED}Reloading systemd daemon...${NC}"
  sudo systemctl daemon-reload

  echo -e "${GREEN}The sqlite-web service has been uninstalled.${NC}"
}

# Main loop for the menu
while true; do
  show_menu
  read -r choice
  case $choice in
    1) install_service ;;
    2) manage_service ;;
    3) uninstall_service ;;
    4) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
  esac
done
