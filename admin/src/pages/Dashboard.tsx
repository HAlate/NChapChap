import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import StatCard from '../components/StatCard';

const Dashboard = () => {
  const [stats, setStats] = useState({
    pendingPurchases: 0,
    totalUsers: 0,
    totalRevenue: 0,
    todayTransactions: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      // Fetch pending purchases count
      const { count: pendingCount } = await supabase
        .from('token_purchases')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');

      // Fetch total users
      const { count: usersCount } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true });

      // Fetch total revenue (validated purchases)
      const { data: revenueData } = await supabase
        .from('token_purchases')
        .select('total_amount')
        .eq('status', 'validated');

      const totalRevenue = revenueData?.reduce((sum, item) => sum + item.total_amount, 0) || 0;

      // Fetch today's transactions
      const today = new Date().toISOString().split('T')[0];
      const { count: todayCount } = await supabase
        .from('token_purchases')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', today);

      setStats({
        pendingPurchases: pendingCount || 0,
        totalUsers: usersCount || 0,
        totalRevenue,
        todayTransactions: todayCount || 0,
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Chargement...</div>;
  }

  return (
    <div className="dashboard">
      <h1>Vue d'ensemble</h1>
      
      <div className="stats-grid">
        <StatCard
          title="Achats en attente"
          value={stats.pendingPurchases}
          icon="⏳"
          color="#FF9800"
        />
        <StatCard
          title="Utilisateurs"
          value={stats.totalUsers}
          icon="👥"
          color="#2196F3"
        />
        <StatCard
          title="Revenus total"
          value={`${stats.totalRevenue.toLocaleString()} XOF`}
          icon="💰"
          color="#4CAF50"
        />
        <StatCard
          title="Transactions aujourd'hui"
          value={stats.todayTransactions}
          icon="📈"
          color="#9C27B0"
        />
      </div>

      <div className="dashboard-sections">
        <div className="section">
          <h2>Activité récente</h2>
          <p className="placeholder">Les transactions récentes apparaîtront ici...</p>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
