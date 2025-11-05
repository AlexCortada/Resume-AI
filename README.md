# Resume AI - Local Resume Customization Tool

AI-powered resume customization that runs locally on your server. Perfect for job applications with privacy in mind.

## Features

- 🤖 Local AI processing using Ollama
- 📝 Customizes resumes based on job descriptions
- 🎨 Multiple professional templates
- 📄 PDF export
- 🔒 100% local - no data leaves your server

## Quick Start

### Prerequisites
- Ubuntu 20.04/22.04 LTS
- 4GB+ RAM, 2+ vCPUs
- 20GB+ free storage

### Installation

```bash
# Clone and setup
git clone https://github.com/yourusername/resume-ai.git
cd resume-ai
chmod +x setup.sh start.sh
./setup.sh

Usage
bash

# Start the application
./start.sh

# Access via web browser
# http://your-server-ip:5000

How It Works

    Paste your resume and job description

    AI customizes your resume to match the job

    Download professionally formatted PDF

Models Supported

    llama3.1:8b (default)

    llama3.2:3b (lighter)

    Other Ollama models

Configuration

Edit resume_app.py to:

    Change AI model

    Modify templates

    Adjust PDF settings