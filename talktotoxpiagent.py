import sys
import json
import pandas as pd
import re

class Response:
    def __init__(self, message):
        self.message = message

    def to_dict(self):
        return {"message": self.message}

    def __str__(self):
        return self.message

def get_chemicals(input_message=None):
    #Reads in chemical list containing unique DTXSIDs and their corresponding chemicals
    chemical_data = pd.read_csv("FinalChemicalList.csv")

    #Map DTXSIDs to their corresponding chemical
    dtxsid_vector = chemical_data['DTXSID'].tolist()
    dtxsid_to_name = dict(zip(chemical_data['DTXSID'], chemical_data['PREFERRED NAME']))

    if input_message:    
        #Grep pattern matches any found DTXSID in the input message
        pattern = r'\b(' + '|'.join(map(re.escape, dtxsid_vector)) + r')\b'
        found_dtx = re.findall(pattern, input_message, flags=re.IGNORECASE)       

        #Removes duplicates
        found_dtx = list(dict.fromkeys(found_dtx))        

        if found_dtx:
            #Get names of chemicals for the retrieved DTXSIDs
            found_chemicals = [dtxsid_to_name[dtxsid.upper()] for dtxsid in found_dtx]      

            #Ensures the number of chemicals is >3 and <5
            if len(found_chemicals) < 3:
                found_chemicals += ["Placeholder Chemical"] * (3 - len(found_chemicals))
            elif len(found_chemicals) > 5:
                found_chemicals = found_chemicals[:5]
        #If no other chemicals are found, placeholders are put in
        else:
            found_chemicals = ["Placeholder Chemical"] * 3
        
        return found_chemicals
    else:
        #Default if no input message is received/processed
        return ['Chemical A', 'Chemical B', 'Chemical C']

#Gets response based on input message
def get_message(input_message):
    import pickle
    #Load the serialized query engine from pickle file (created by pickleagent.py)
    try:
        with open('query_engine.pkl', 'rb') as file:
            query_engine = pickle.load(file)
    except Exception as e:
        print(f"Error loading query engine: {e}")
        query_engine = None

    #Function to query the RAG engine
    def query_engine_response(input_message):
        if query_engine is None:
            print("Query engine not initialized.")
            return None
        try:
            response = query_engine.query(input_message)
            return response
        except Exception as e:
            print(f"Error during query execution: {e}")
            return None

    #Calls query engine to respond to input message
    response = query_engine_response(input_message)
    if response:
        return response
    else:
        print("No response provided.")


def getfile(found_dtx):
    import subprocess
    import pandas as pd
    import tempfile
    import os

    #Write found_dtx to a temporary CSV file so it can be interpreted by accessctx.r
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
        temp_input_path = f.name
        if isinstance(found_dtx, pd.DataFrame):
            found_dtx.to_csv(f, index=False)
        else:
            raise ValueError("found_dtx must be a pandas DataFrame.")

    try:
        #RunR script and get stdoout string
        result = subprocess.run(
            ['Rscript', '/mnt/data/AccessCTX.R', temp_input_path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        #CSV string from AccessCTX.R
        return result.stdout

    except subprocess.CalledProcessError as e:
        print("Error while running R script:", e.stderr)
        return None

    finally:
        os.remove(temp_input_path)

def main():
    #Check that there are three arguments, one of each type
    try:
        if len(sys.argv) < 3:
            raise ValueError("Expected an action as an argument (message or chemicals or file)")
        
        action = sys.argv[1]
        
        if action == 'message':
            if len(sys.argv) != 3:
                raise ValueError("Expected one argument for the 'message' action")
            input_message = sys.argv[2]
            response = get_message(input_message)
            
            #Extract string message from response
            if isinstance(response, Response):
                processed_message = response.message
            elif isinstance(response, (tuple, list)):
                processed_message = response[0].message if isinstance(response[0], Response) else str(response[0])
            else:
                processed_message = str(response)
                
            chemicals = get_chemicals(processed_message)
            
            #Make sure result is in a JSON serializable format
            result_dict = {
                "response": processed_message, 
                "chemicals": chemicals
            }
            print(json.dumps(result_dict))
        #Processes chemical output
        elif action == 'chemicals':
            chemicals = get_chemicals()
            print(json.dumps(chemicals))
        #Processes file output, using found_dtx variable initialized in get_chemicals
        elif action == 'file':
            file_name = getfile(found_dtx)
            print(json.dumps(file_name))
        else:
            raise ValueError("Unknown action, expected 'message' or 'chemicals'")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()