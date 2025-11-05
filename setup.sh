#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting Resume AI Setup..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install system dependencies
echo "📥 Installing system dependencies..."
sudo apt install -y python3-pip python3-venv nginx git curl build-essential wkhtmltopdf

# Install Ollama
echo "🤖 Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p uploads output logs

# Setup Python environment
echo "🐍 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python packages
echo "📚 Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

# Download AI model in background
echo "📥 Downloading AI model (this may take a while)..."
ollama pull llama3.1:8b &

# Create startup script
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python resume_app.py
EOF

chmod +x start.sh

# Create systemd service file
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/resume-ai.service > /dev/null << EOF
[Unit]
Description=Resume AI Application
After=network.target ollama.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
Environment=PATH=$PWD/venv/bin
ExecStart=$PWD/venv/bin/python resume_app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Wait for Ollama download to complete
echo "⏳ Waiting for AI model download to complete..."
wait

echo "✅ Setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Start the application: ./start.sh"
echo "2. Or enable as service: sudo systemctl enable resume-ai && sudo systemctl start resume-ai"
echo "3. Access at: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "📖 For production:"
echo "   - Configure nginx reverse proxy"
echo "   - Set up SSL certificates"
echo "   - Update SECRET_KEY in resume_app.py"