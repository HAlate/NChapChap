import { Link, useLocation } from 'react-router-dom';

const Sidebar = () => {
  const location = useLocation();

  const menuItems = [
    { path: '/', icon: '📊', label: 'Dashboard' },
    { path: '/pending-purchases', icon: '⏳', label: 'Achats en attente' },
    { path: '/users', icon: '👥', label: 'Utilisateurs' },
    { path: '/token-packages', icon: '💎', label: 'Packages Jetons' },
    { path: '/transactions', icon: '💳', label: 'Transactions' },
  ];

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <h2>🚗 ZedGo Admin</h2>
      </div>
      <nav className="sidebar-nav">
        {menuItems.map((item) => (
          <Link
            key={item.path}
            to={item.path}
            className={`nav-item ${location.pathname === item.path ? 'active' : ''}`}
          >
            <span className="nav-icon">{item.icon}</span>
            <span className="nav-label">{item.label}</span>
          </Link>
        ))}
      </nav>
    </aside>
  );
};

export default Sidebar;
