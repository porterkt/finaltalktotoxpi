from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import json

app = Flask(__name__)
CORS(app) 

@app.route('/api/message', methods=['POST'])
#Handles message creation, linked in RAG script
def handle_message():
    content = request.json
    message = content['message']

    try:
        result = subprocess.run(
            ['python3', 'talktotoxpiagent.py', 'message', message],
            capture_output=True,
            text=True,
            check=True
        )
        import re


        #Stores output and error messaging from result
        stdout_output = result.stdout.strip()
        stderr_output = result.stderr.strip()

        #Try to extract JSON portion from stdout_output
        json_match = re.search(r'\{.*\}', stdout_output, re.DOTALL)

        if json_match:
            json_data = json_match.group(0)  #Extract JSON part of output
            output = json.loads(json_data)
        else:
            raise ValueError("No valid JSON found in subprocess output")
        
        #Debugging logs
        print(f"Subprocess stdout: {stdout_output}")
        print(f"Subprocess stderr: {stderr_output}")

        if not stdout_output:
            raise ValueError("No output from subprocess")

        #Stores final values for responses and chemicals
        response = output['response']
        chemicals = output['chemicals']
    except subprocess.CalledProcessError as e:
        print(f"Subprocess error: {e.stderr}")
        response = f"Subprocess error: {e}\n{e.stderr}"
        chemicals = []
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        print(f"Failed stdout output: {stdout_output}") 
        response = "Error decoding JSON response from subprocess"
        chemicals = []
    except ValueError as e:
        print(f"Value error: {e}")
        response = str(e)
        chemicals = []

    return jsonify({'response': response, 'chemicals': chemicals})

if __name__ == '__main__':
    app.run(debug=True)