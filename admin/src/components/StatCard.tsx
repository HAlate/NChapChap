interface StatCardProps {
  title: string;
  value: string | number;
  icon: string;
  trend?: string;
  color?: string;
}

const StatCard = ({ title, value, icon, trend, color = '#4CAF50' }: StatCardProps) => {
  return (
    <div className="stat-card" style={{ borderLeftColor: color }}>
      <div className="stat-icon" style={{ backgroundColor: `${color}20` }}>
        {icon}
      </div>
      <div className="stat-content">
        <h3 className="stat-title">{title}</h3>
        <p className="stat-value">{value}</p>
        {trend && <span className="stat-trend">{trend}</span>}
      </div>
    </div>
  );
};

export default StatCard;
