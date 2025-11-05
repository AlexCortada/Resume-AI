class AIProcessor:
    def __init__(self, config):
        self.config = config
    
    def customize_resume(self, resume_text, job_description):
        """Customize resume using AI based on job description"""
        try:
            # First, check if Ollama is running
            if not self._check_ollama_health():
                return f"Ollama is not running. Please start it with: sudo systemctl start ollama\n\nUsing original resume:\n{resume_text}"
            
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
            
            logger.info(f"Ollama response status: {response.status_code}")
            
            if response.status_code == 200:
                response_data = response.json()
                logger.info(f"Ollama response keys: {response_data.keys()}")
                
                # Handle different possible response formats
                if 'response' in response_data:
                    customized = response_data['response']
                elif 'text' in response_data:
                    customized = response_data['text']
                else:
                    customized = str(response_data)
                    
                logger.info("AI customization completed successfully")
                return customized
            else:
                error_msg = f"Ollama API error: {response.status_code} - {response.text}"
                logger.error(error_msg)
                return f"{error_msg}\n\nUsing original resume:\n{resume_text}"
                
        except requests.exceptions.ConnectionError:
            error_msg = "Cannot connect to Ollama. Please make sure it's running on localhost:11434"
            logger.error(error_msg)
            return f"{error_msg}\n\nUsing original resume:\n{resume_text}"
        except Exception as e:
            error_msg = f"AI processing failed: {str(e)}"
            logger.error(error_msg)
            return f"{error_msg}\n\nUsing original resume:\n{resume_text}"
    
    def _check_ollama_health(self):
        """Check if Ollama is running and accessible"""
        try:
            response = requests.get(f"{self.config['OLLAMA_URL']}/api/tags", timeout=10)
            return response.status_code == 200
        except:
            return False
    
    def _build_prompt(self, resume_text, job_description):
        return f"""
TASK: Customize the resume to perfectly match the job description.

JOB DESCRIPTION:
{job_description}

ORIGINAL RESUME:
{resume_text}

INSTRUCTIONS:
1. Analyze the job description and identify the key requirements
2. Rewrite the resume to highlight relevant experience using the same keywords
3. Keep all factual information accurate
4. Maintain professional formatting
5. Focus on making the resume ATS-friendly
6. Return ONLY the improved resume content, no explanations

CUSTOMIZED RESUME:
"""
