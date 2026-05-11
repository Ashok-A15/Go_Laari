import json
import pickle
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

def train_intent_model():
    # 1. Load Data
    with open('intents.json', 'r') as f:
        data = json.load(f)

    # 2. Prepare training pairs
    X = [] # Patterns
    y = [] # Tags (Intents)
    
    for intent in data['intents']:
        for pattern in intent['patterns']:
            X.append(pattern.lower())
            y.append(intent['tag'])

    # 3. Create ML Pipeline
    # TfidfVectorizer: Converts words to numbers
    # LogisticRegression: Classifies the numbers into categories
    model_pipeline = Pipeline([
        ('tfidf', TfidfVectorizer(ngram_range=(1, 2))),
        ('clf', LogisticRegression(solver='lbfgs', max_iter=1000))
    ])

    # 4. Train the model
    print("Training GoLorry Intent Model...")
    model_pipeline.fit(X, y)

    # 5. Save the trained model
    with open('intent_model.pkl', 'wb') as f:
        pickle.dump(model_pipeline, f)
    
    print("Model trained and saved as 'intent_model.pkl'")

if __name__ == "__main__":
    train_intent_model()
