import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './styles.css'; // Import the CSS file

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
    <div className="app-container">
      <h1 className="app-title">Task Tracker</h1>
      <div className="input-container">
        <input
          type="text"
          placeholder="Title"
          value={title}
          onChange={e => setTitle(e.target.value)}
          className="input-field"
        />
        <input
          type="text"
          placeholder="Description"
          value={description}
          onChange={e => setDescription(e.target.value)}
          className="input-field"
        />
        <button onClick={createTask} className="create-button">Create Task</button>
      </div>
      <ul className="task-list">
        {tasks.map(task => (
          <li key={task.id} className="task-item">
            <span className="task-title">{task.title}</span> - <span className="task-description">{task.description}</span>
            <button onClick={() => deleteTask(task.id)} className="delete-button">Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;
