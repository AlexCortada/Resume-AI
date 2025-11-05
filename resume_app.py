from flask import Flask, render_template, request, send_file, jsonify
import requests
import os
import pdfkit
import jinja2
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-key-change-in-production')
    UPLOAD_FOLDER = 'uploads'
    OUTPUT_FOLDER = 'output'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB
    AI_PROVIDER = 'local'
    OLLAMA_MODEL = 'llama3.1:8b'
    OLLAMA_URL = 'http://localhost:11434'

app.config.from_object(Config)

class AIProcessor:
    def __init__(self, config):
        self.config = config
    
    def customize_resume(self, resume_text, job_description):
        """Customize resume using AI based on job description"""
        try:
            prompt = self._build_prompt(resume_text, job_description)
            
            logger.info("Sending request to Ollama...")
            response = requests.post(
                f"{self.config['OLLAMA_URL']}/api/generate",
                json={
                    "model": self.config['OLLAMA_MODEL'],
                    "prompt": prompt,
                    "stream": False
                },
                timeout=120
            )
            
            if response.status_code == 200:
                customized = response.json()['response']
                logger.info("AI customization completed successfully")
                return customized
            else:
                error_msg = f"Ollama API error: {response.status_code}"
                logger.error(error_msg)
                return f"{error_msg}\n\nUsing original resume:\n{resume_text}"
                
        except Exception as e:
            error_msg = f"AI processing failed: {str(e)}"
            logger.error(error_msg)
            return f"{error_msg}\n\nUsing original resume:\n{resume_text}"
    
    def _build_prompt(self, resume_text, job_description):
        return f"""
You are an expert resume writer and ATS (Applicant Tracking System) optimization specialist.

JOB DESCRIPTION:
{job_description}

ORIGINAL RESUME:
{resume_text}

INSTRUCTIONS:
1. Analyze the job description and identify key skills, technologies, and requirements
2. Customize the resume to highlight relevant experience using the same terminology
3. Reorder sections to put most relevant experience first
4. Incorporate keywords from the job description naturally
5. Maintain all factual information and dates accurately
6. Keep the format professional and ATS-friendly
7. Do not invent experience or qualifications

Return ONLY the customized resume content, no explanations.
"""

class PDFFormatter:
    def __init__(self):
        self.template_env = jinja2.Environment(loader=jinja2.FileSystemLoader('templates'))
    
    def generate_pdf(self, resume_data, template_name='modern'):
        """Generate PDF from resume data"""
        try:
            template = self.template_env.get_template(f'{template_name}.html')
            html_content = template.render(resume=resume_data)
            
            options = {
                'page-size': 'Letter',
                'margin-top': '0.5in',
                'margin-right': '0.5in',
                'margin-bottom': '0.5in',
                'margin-left': '0.5in',
                'encoding': "UTF-8",
                'quiet': '',
                'no-outline': None
            }
            
            pdf = pdfkit.from_string(html_content, False, options=options)
            logger.info("PDF generated successfully")
            return pdf
            
        except Exception as e:
            logger.error(f"PDF generation failed: {str(e)}")
            raise

# Initialize processors
ai_processor = AIProcessor(app.config)
formatter = PDFFormatter()

@app.route('/')
def index():
    """Main page"""
    return render_template('index.html')

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'resume-ai'})

@app.route('/process', methods=['POST'])
def process_resume():
    """Process resume customization request"""
    try:
        resume_text = request.form['resume_text']
        job_description = request.form['job_description']
        template = request.form.get('template', 'modern')
        
        logger.info("Starting resume customization process")
        
        # Validate input
        if not resume_text.strip() or not job_description.strip():
            return jsonify({'error': 'Resume and job description are required'}), 400
        
        # AI customization
        customized_resume = ai_processor.customize_resume(resume_text, job_description)
        
        # Prepare resume data
        resume_data = {
            'name': 'Your Name',  # Could be extracted from resume in future
            'email': 'your.email@example.com',
            'phone': '(555) 123-4567',
            'content': customized_resume
        }
        
        # Generate PDF
        pdf_content = formatter.generate_pdf(resume_data, template)
        
        # Save file
        output_path = os.path.join(app.config['OUTPUT_FOLDER'], 'customized_resume.pdf')
        with open(output_path, 'wb') as f:
            f.write(pdf_content)
        
        logger.info("Resume processing completed successfully")
        return send_file(output_path, as_attachment=True, download_name='customized_resume.pdf')
        
    except Exception as e:
        logger.error(f"Resume processing error: {str(e)}")
        return jsonify({'error': str(e)}), 500

def ensure_directories():
    """Ensure required directories exist"""
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)
    os.makedirs('logs', exist_ok=True)

if __name__ == '__main__':
    ensure_directories()
    
    logger.info("Starting Resume AI Application")
    logger.info(f"Ollama URL: {app.config['OLLAMA_URL']}")
    logger.info(f"AI Model: {app.config['OLLAMA_MODEL']}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)