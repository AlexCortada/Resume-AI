cat > setup_resume_ai.sh << 'EOF'
#!/bin/bash

# Resume AI Setup Script
echo "Starting Resume AI setup..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "Installing system dependencies..."
sudo apt install -y python3-pip python3-venv nginx git curl build-essential wkhtmltopdf

# Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Create application directory
echo "Creating application directory..."
mkdir -p ~/resume-ai/{templates,uploads,output}
cd ~/resume-ai

# Create Python virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python packages
echo "Installing Python packages..."
pip install --upgrade pip
pip install flask requests jinja2 pdfkit

# Pull Ollama model (in background)
echo "Pulling Ollama model (this may take a while)..."
ollama pull llama3.1:8b &

# Create the main application file
echo "Creating application files..."

cat > resume_app.py << 'SCRIPT_EOF'
from flask import Flask, render_template, request, send_file, jsonify
import requests
import os
import pdfkit
import jinja2

app = Flask(__name__)

# Configuration
class Config:
    SECRET_KEY = 'your-secret-key-change-in-production'
    UPLOAD_FOLDER = 'uploads'
    OUTPUT_FOLDER = 'output'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024
    AI_PROVIDER = 'local'
    OLLAMA_MODEL = 'llama3.1:8b'
    OLLAMA_URL = 'http://localhost:11434'

app.config.from_object(Config)

class AIProcessor:
    def __init__(self, config):
        self.config = config
    
    def customize_resume(self, resume_text, job_description):
        try:
            prompt = f"""
            You are an expert resume writer. Analyze the job description and customize the resume to match it perfectly.
            
            JOB DESCRIPTION:
            {job_description}
            
            ORIGINAL RESUME:
            {resume_text}
            
            Instructions:
            1. Extract the most important keywords and requirements from the job description
            2. Rewrite the resume to highlight relevant experience using the same terminology
            3. Reorder sections to put most relevant experience first
            4. Keep all factual information accurate
            5. Maintain professional formatting
            6. Return ONLY the improved resume content
            
            Customized Resume:
            """
            
            response = requests.post(
                f"{self.config['OLLAMA_URL']}/api/generate",
                json={
                    "model": self.config['OLLAMA_MODEL'],
                    "prompt": prompt,
                    "stream": False
                },
                timeout=120
            )
            return response.json()['response']
        except Exception as e:
            return f"AI customization failed. Using original resume.\nError: {str(e)}\n\n{resume_text}"

class PDFFormatter:
    def __init__(self):
        self.template_env = jinja2.Environment(loader=jinja2.FileSystemLoader('templates'))
    
    def generate_pdf(self, resume_data, template_name='modern'):
        template = self.template_env.get_template(f'{template_name}.html')
        html_content = template.render(resume=resume_data)
        
        options = {
            'page-size': 'Letter',
            'margin-top': '0.5in',
            'margin-right': '0.5in',
            'margin-bottom': '0.5in',
            'margin-left': '0.5in',
            'encoding': "UTF-8",
            'quiet': ''
        }
        
        return pdfkit.from_string(html_content, False, options=options)

# Initialize processors
ai_processor = AIProcessor(app.config)
formatter = PDFFormatter()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/process', methods=['POST'])
def process_resume():
    try:
        resume_text = request.form['resume_text']
        job_description = request.form['job_description']
        template = request.form.get('template', 'modern')
        
        print("Processing resume customization...")
        customized_resume = ai_processor.customize_resume(resume_text, job_description)
        
        resume_data = {
            'name': 'Your Name',  # In future, parse this from resume
            'email': 'your.email@example.com',
            'phone': '(555) 123-4567',
            'content': customized_resume
        }
        
        pdf_content = formatter.generate_pdf(resume_data, template)
        
        output_path = os.path.join(app.config['OUTPUT_FOLDER'], 'customized_resume.pdf')
        with open(output_path, 'wb') as f:
            f.write(pdf_content)
        
        return send_file(output_path, as_attachment=True, download_name='customized_resume.pdf')
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)
    
    print("Resume AI starting on http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
SCRIPT_EOF

# Create templates
echo "Creating templates..."

cat > templates/base.html << 'TEMPLATE_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AI Resume Customizer</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; font-weight: bold; color: #2c3e50; }
        textarea, select { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; box-sizing: border-box; }
        textarea { height: 200px; resize: vertical; font-family: monospace; }
        button { background: #2c3e50; color: white; padding: 15px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; width: 100%; }
        button:hover { background: #34495e; }
        h1 { color: #2c3e50; text-align: center; margin-bottom: 30px; }
        .info { background: #e8f4fd; padding: 15px; border-radius: 4px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        {% block content %}{% endblock %}
    </div>
</body>
</html>
TEMPLATE_EOF

cat > templates/index.html << 'INDEX_EOF'
{% extends "base.html" %}

{% block content %}
<h1>AI Resume Customizer</h1>

<div class="info">
    <strong>How to use:</strong><br>
    1. Paste your current resume in the first box<br>
    2. Paste the job description in the second box<br>
    3. Select a template and click Generate<br>
    4. Download your customized PDF resume
</div>

<form method="POST" action="/process">
    <div class="form-group">
        <label for="resume_text">Your Resume:</label>
        <textarea id="resume_text" name="resume_text" required placeholder="Paste your complete resume here..."></textarea>
    </div>
    
    <div class="form-group">
        <label for="job_description">Job Description:</label>
        <textarea id="job_description" name="job_description" required placeholder="Paste the job description here..."></textarea>
    </div>
    
    <div class="form-group">
        <label for="template">Resume Template:</label>
        <select id="template" name="template">
            <option value="modern">Modern</option>
            <option value="professional">Professional</option>
        </select>
    </div>
    
    <button type="submit">Generate Customized Resume</button>
</form>
{% endblock %}
INDEX_EOF

cat > templates/modern.html << 'MODERN_EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{{ resume.name }} - Resume</title>
    <style>
        body { font-family: 'Helvetica', Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 8.5in; margin: 0 auto; padding: 0.5in; }
        .header { text-align: center; margin-bottom: 1em; border-bottom: 2px solid #2c3e50; padding-bottom: 0.5em; }
        .name { font-size: 24px; font-weight: bold; color: #2c3e50; margin-bottom: 0.2em; }
        .contact { color: #7f8c8d; margin-bottom: 0.5em; }
        .section { margin-bottom: 1em; }
        .section-title { font-size: 18px; font-weight: bold; color: #2c3e50; border-bottom: 1px solid #bdc3c7; padding-bottom: 0.2em; margin-bottom: 0.5em; }
        .content { white-space: pre-line; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="name">{{ resume.name }}</div>
            <div class="contact">{{ resume.email }} | {{ resume.phone }}</div>
        </div>
        
        <div class="content">{{ resume.content }}</div>
    </div>
</body>
</html>
MODERN_EOF

cat > templates/professional.html << 'PRO_EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{{ resume.name }} - Resume</title>
    <style>
        body { font-family: 'Times New Roman', serif; line-height: 1.4; color: #000; margin: 0; padding: 0; }
        .container { max-width: 8.5in; margin: 0 auto; padding: 0.5in; }
        .header { text-align: center; margin-bottom: 1em; }
        .name { font-size: 22px; font-weight: bold; margin-bottom: 0.2em; }
        .contact { font-size: 14px; margin-bottom: 0.5em; }
        .section { margin-bottom: 1em; }
        .section-title { font-size: 16px; font-weight: bold; border-bottom: 1px solid #000; padding-bottom: 0.2em; margin-bottom: 0.5em; }
        .content { white-space: pre-line; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="name">{{ resume.name }}</div>
            <div class="contact">{{ resume.email }} | {{ resume.phone }}</div>
        </div>
        
        <div class="content">{{ resume.content }}</div>
    </div>
</body>
</html>
PRO_EOF

# Create startup script
cat > start_resume_ai.sh << 'START_EOF'
#!/bin/bash
cd ~/resume-ai
source venv/bin/activate
python resume_app.py
START_EOF

chmod +x start_resume_ai.sh

# Wait for Ollama to finish downloading
echo "Waiting for Ollama model to complete download..."
wait

echo "Setup complete!"
echo ""
echo "To start the application:"
echo "1. cd ~/resume-ai"
echo "2. ./start_resume_ai.sh"
echo ""
echo "Then access it at: http://your-vm-ip:5000"
echo ""
echo "Note: The first AI request might take a minute as the model loads."
EOF

# Make the setup script executable
chmod +x setup_resume_ai.sh