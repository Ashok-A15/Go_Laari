import json
import random
import pickle
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import spacy
import firebase_admin
import google.generativeai as genai
from firebase_admin import credentials, firestore
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="GoLorry AI Backend")

# 1. Initialize Gemini AI (Phase 6)
GENIMNI_API_KEY = "AIzaSyChcZi_oo6iKpg_I34UuGd1zSSzqeFEdc4"
genai.configure(api_key=GENIMNI_API_KEY)
llm_model = genai.GenerativeModel('gemini-1.5-flash')

# 2. Initialize Firebase Admin
# NOTE: You need to place your 'serviceAccountKey.json' in the backend folder
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase Admin initialized successfully")
except Exception as e:
    print(f"Firebase Init Warning: {e}. Order tracking will be limited.")
    db = None

# Load spaCy NLP model (Requires: python -m spacy download en_core_web_sm)
try:
    nlp = spacy.load("en_core_web_sm")
except:
    print("spaCy model not found. Run: python -m spacy download en_core_web_sm")
    nlp = None

# Allow Flutter to communicate with Python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mock session storage (In real app, use Redis or Database)
user_sessions = {}

# Load the trained model
try:
    with open('intent_model.pkl', 'rb') as f:
        model = pickle.load(f)
    
    with open('intents.json', 'r') as f:
        intents_data = json.load(f)
except Exception as e:
    print(f"Error loading model: {e}")

class ChatRequest(BaseModel):
    message: str
    user_id: str = "default_user"

def extract_entities(text):
    if not nlp: return {}
    doc = nlp(text)
    entities = {
        "locations": [ent.text for ent in doc.ents if ent.label_ in ["GPE", "LOC", "FAC"]],
        "dates": [ent.text for ent in doc.ents if ent.label_ == "DATE"],
    }
    
    # Smart Fallback: Check for common city names if spaCy misses them
    common_cities = ["mysore", "mysuru", "bangalore", "bengaluru", "delhi", "mumbai", "chennai", "noida", "pune", "hyderabad"]
    words = text.lower().split()
    for word in words:
        if word in common_cities and word.capitalize() not in entities["locations"]:
            entities["locations"].append(word.capitalize())
            
    return entities

def humanize_response(raw_data: str, user_input: str):
    """Uses Gemini to make the response sound natural and professional."""
    try:
        prompt = f"""
        You are GoLorry AI, a premium logistics assistant.
        The user said: "{user_input}"
        Our internal logic generated this technical response: "{raw_data}"
        
        Rewrite this into a friendly, helpful, and professional response in 1-2 sentences. 
        Maintain a 'premium' and 'trustworthy' tone. Don't use placeholders.
        """
        response = llm_model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini Error: {e}")
        return raw_data # Fallback to technical response

@app.post("/chat")
async def chat(request: ChatRequest):
    user_message = request.message
    user_id = request.user_id
    
    # Initialize session if new
    if user_id not in user_sessions:
        user_sessions[user_id] = {"origin": None, "destination": None, "context": None}
    
    session = user_sessions[user_id]

    # 1. Predict Intent
    intent_tag = model.predict([user_message.lower()])[0]
    probabilities = model.predict_proba([user_message.lower()])
    max_prob = max(probabilities[0])
    
    # Extract entities regardless of intent
    entities = extract_entities(user_message)

    # 2. LOGIC: TRACK ORDER (Live Database Query)
    if intent_tag == "track_order":
        if db:
            try:
                # Query Firestore for active bookings of this user
                bookings_ref = db.collection('bookings').where('userId', '==', user_id).limit(1).get()
                
                if bookings_ref:
                    booking = bookings_ref[0].to_dict()
                    status = booking.get('status', 'Processing')
                    origin = booking.get('pickupAddress', 'Unknown')
                    dest = booking.get('dropAddress', 'Unknown')
                    
                    raw_resp = f"I found your active booking from {origin} to {dest}. Current Status: {status}."
                    final_resp = humanize_response(raw_resp, user_message)
                    return {"response": final_resp, "intent": "track_order", "live_data": True}
                else:
                    raw_resp = "You don't have any active bookings right now."
                    final_resp = humanize_response(raw_resp, user_message)
                    return {"response": final_resp, "intent": "track_order"}
            except Exception as e:
                print(f"Firestore Error: {e}")

    # 3. LOGIC: SLOT FILLING FOR BOOKING
    if intent_tag == "book_truck" or session["context"] == "awaiting_booking_info":
        session["context"] = "awaiting_booking_info"
        
        # Update session with any found locations
        found_locations = entities["locations"]
        
        # If no entities found but it's a single word, treat it as a location
        if not found_locations and len(user_message.split()) <= 2:
            found_locations = [user_message.strip().capitalize()]

        for loc in found_locations:
            if not session["origin"]:
                session["origin"] = loc
            elif not session["destination"] and loc.lower() != session["origin"].lower():
                session["destination"] = loc

        # Check what's missing
        if not session["origin"]:
            raw_resp = "I'd love to help with that! Where should the truck pick up the load from?"
            final_resp = humanize_response(raw_resp, user_message)
            return {"response": final_resp, "intent": "book_truck", "session": session}
        
        if not session["destination"]:
            raw_resp = f"Got it, from {session['origin']}. And where is the destination?"
            final_resp = humanize_response(raw_resp, user_message)
            return {"response": final_resp, "intent": "book_truck", "session": session}
        
        # If everything is found
        raw_resp = f"Perfect! I've noted a booking from {session['origin']} to {session['destination']}. I'm checking for available lorries now..."
        session["context"] = None # Reset
        user_sessions[user_id] = {"origin": None, "destination": None, "context": None} # Clear for next time
        final_resp = humanize_response(raw_resp, user_message)
        return {"response": final_resp, "intent": "book_truck", "session": session}

    # 3. Standard response for other intents
    if max_prob < 0.3:
        return {"response": "I'm not sure I understand. I can help with booking and tracking.", "intent": "unknown"}

    response = "I'm not sure how to help."
    for intent in intents_data['intents']:
        if intent['tag'] == intent_tag:
            response = random.choice(intent['responses'])
            break
            
    final_resp = humanize_response(response, user_message)
    return {"response": final_resp, "intent": intent_tag, "entities": entities}

@app.get("/")
def home():
    return {"status": "GoLorry AI Backend is running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
