const Header = () => {
  return (
    <header className="header">
      <div className="header-content">
        <h1 className="header-title">Dashboard Admin</h1>
        <div className="header-actions">
          <div className="user-info">
            <span className="user-name">Administrateur</span>
            <div className="user-avatar">👤</div>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
