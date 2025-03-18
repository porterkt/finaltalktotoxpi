import os
import pickle
from dotenv import load_dotenv
from llama_index.llms.azure_openai import AzureOpenAI
from llama_index.embeddings.azure_openai import AzureOpenAIEmbedding
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader

load_dotenv()
api_key = os.getenv("AZURE_OPENAI_API_KEY")
azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
api_version = os.getenv("OPENAI_API_VERSION")

if not api_key or not azure_endpoint or not api_version:
    raise ValueError("Environment variables are not set correctly. Please check your .env file and ensure it is in your root directory.")

#Initialize Azure OpenAI, engine, and model retrieved from LiteLLM
llm = AzureOpenAI(
    engine="azure-gpt-4o",
    model="gpt-4o",
    api_key=os.getenv("AZURE_OPENAI_API_KEY"),
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_version=os.getenv("OPENAI_API_VERSION")
)

#Embed models, deployment name retrieved from Lite LLM
embed_model = AzureOpenAIEmbedding(
    deployment_name="text-embedding-ada-002",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_API_KEY"),
    api_version=os.getenv("OPENAI_API_VERSION")
)

#Read and process documents
try:
    #Likely that change in directory will be needed
    documents = SimpleDirectoryReader("./2ndEJS").load_data()
except Exception as e:
    print(f"Error loading documents: {e}")
    documents = []

#Build the vector store index from the documents if documents are loaded successfully
if documents:
    try:
        index = VectorStoreIndex.from_documents(documents, embed_model=embed_model)
        query_engine = index.as_query_engine(llm=llm)
        #Serialize the query engine to a file
        with open('query_engine.pkl', 'wb') as file:
            pickle.dump(query_engine, file)
        print("Query engine created and serialized to 'query_engine.pkl'.")
    except Exception as e:
        print(f"Error during query execution: {e}")
else:
    print("No documents found or error in loading documents. Aborting index creation and query.")