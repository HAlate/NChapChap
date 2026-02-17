import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import Dashboard from './pages/Dashboard';
import PendingPurchases from './pages/PendingPurchases';
import Users from './pages/Users';
import './App.css'

function App() {
  return (
    <Router>
      <div className="app-container">
        <Sidebar />
        <div className="main-content">
          <Header />
          <div className="content-wrapper">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/pending-purchases" element={<PendingPurchases />} />
              <Route path="/users" element={<Users />} />
              <Route path="/token-packages" element={<div className="placeholder">Packages de jetons - À venir</div>} />
              <Route path="/transactions" element={<div className="placeholder">Historique des transactions - À venir</div>} />
            </Routes>
          </div>
        </div>
      </div>
    </Router>
  )
}

export default App
