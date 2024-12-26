from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from pymongo import MongoClient
import os

app = FastAPI()

# Enable CORS for all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
client = MongoClient(MONGO_URL)
db = client.tasktracker
tasks_collection = db.tasks

class Task(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    completed: bool = False

@app.post("/tasks/", response_model=Task)
def create_task(task: Task):
    if tasks_collection.find_one({"id": task.id}):
        raise HTTPException(status_code=400, detail="Task with this ID already exists")
    tasks_collection.insert_one(task.dict())
    return task

@app.get("/tasks/", response_model=List[Task])
def read_tasks():
    tasks = list(tasks_collection.find())
    return tasks

@app.get("/tasks/{task_id}", response_model=Task)
def read_task(task_id: int):
    task = tasks_collection.find_one({"id": task_id})
    if task:
        return task
    raise HTTPException(status_code=404, detail="Task not found")

@app.put("/tasks/{task_id}", response_model=Task)
def update_task(task_id: int, updated_task: Task):
    result = tasks_collection.update_one({"id": task_id}, {"$set": updated_task.dict()})
    if result.matched_count:
        return updated_task
    raise HTTPException(status_code=404, detail="Task not found")

@app.delete("/tasks/{task_id}", response_model=Task)
def delete_task(task_id: int):
    task = tasks_collection.find_one_and_delete({"id": task_id})
    if task:
        return task
    raise HTTPException(status_code=404, detail="Task not found")
