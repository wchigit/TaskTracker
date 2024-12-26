import React, { useState, useEffect } from 'react';
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL.startsWith('http')
  ? process.env.REACT_APP_API_URL
  : `https://${process.env.REACT_APP_API_URL}`;

function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');

  useEffect(() => {
    axios.get(`${API_URL}/tasks/`)
      .then(response => setTasks(response.data))
      .catch(error => console.error(error));
  }, []);

  const createTask = () => {
    const newTask = { id: Date.now(), title, description, completed: false };
    axios.post(`${API_URL}/tasks/`, newTask)
      .then(response => setTasks([...tasks, response.data]))
      .catch(error => console.error(error));
  };

  const deleteTask = (id) => {
    axios.delete(`${API_URL}/tasks/${id}`)
      .then(() => setTasks(tasks.filter(task => task.id !== id)))
      .catch(error => console.error(error));
  };

  return (
    <div>
      <h1>Task Tracker</h1>
      <input
        type="text"
        placeholder="Title"
        value={title}
        onChange={e => setTitle(e.target.value)}
      />
      <input
        type="text"
        placeholder="Description"
        value={description}
        onChange={e => setDescription(e.target.value)}
      />
      <button onClick={createTask}>Create Task</button>
      <ul>
        {tasks.map(task => (
          <li key={task.id}>
            {task.title} - {task.description}
            <button onClick={() => deleteTask(task.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;
