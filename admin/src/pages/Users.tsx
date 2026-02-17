import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { User } from '../types';

const Users = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState<string>('all');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      let query = supabase
        .from('users')
        .select('*')
        .order('created_at', { ascending: false });

      if (filterType !== 'all') {
        query = query.eq('user_type', filterType);
      }

      const { data, error } = await query;
      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [filterType]);

  const filteredUsers = users.filter(user =>
    user.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.phone.includes(searchTerm) ||
    user.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getUserTypeIcon = (type: string) => {
    switch (type) {
      case 'driver': return '🚗';
      case 'restaurant': return '🍽️';
      case 'merchant': return '🏪';
      case 'rider': return '🛵';
      default: return '👤';
    }
  };

  if (loading) {
    return <div className="loading">Chargement...</div>;
  }

  return (
    <div className="users-page">
      <div className="page-header">
        <h1>Gestion des utilisateurs</h1>
        <div className="header-actions">
          <input
            type="text"
            placeholder="Rechercher..."
            className="search-input"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="filters">
        <button 
          className={filterType === 'all' ? 'active' : ''}
          onClick={() => setFilterType('all')}
        >
          Tous
        </button>
        <button 
          className={filterType === 'driver' ? 'active' : ''}
          onClick={() => setFilterType('driver')}
        >
          🚗 Chauffeurs
        </button>
        <button 
          className={filterType === 'restaurant' ? 'active' : ''}
          onClick={() => setFilterType('restaurant')}
        >
          🍽️ Restaurants
        </button>
        <button 
          className={filterType === 'merchant' ? 'active' : ''}
          onClick={() => setFilterType('merchant')}
        >
          🏪 Marchands
        </button>
        <button 
          className={filterType === 'rider' ? 'active' : ''}
          onClick={() => setFilterType('rider')}
        >
          🛵 Livreurs
        </button>
      </div>

      <div className="users-table">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Nom</th>
              <th>Téléphone</th>
              <th>Email</th>
              <th>Date d'inscription</th>
              <th>Statut</th>
            </tr>
          </thead>
          <tbody>
            {filteredUsers.map((user) => (
              <tr key={user.id}>
                <td>
                  <span className="user-type-icon">
                    {getUserTypeIcon(user.user_type)}
                  </span>
                </td>
                <td className="user-name">{user.full_name}</td>
                <td>{user.phone}</td>
                <td>{user.email || '-'}</td>
                <td>{new Date(user.created_at).toLocaleDateString('fr-FR')}</td>
                <td>
                  <span className={`status-badge ${user.is_visible ? 'visible' : 'invisible'}`}>
                    {user.is_visible !== undefined 
                      ? (user.is_visible ? '✓ Visible' : '✗ Invisible')
                      : 'Actif'}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {filteredUsers.length === 0 && (
        <div className="empty-state">
          <p>Aucun utilisateur trouvé</p>
        </div>
      )}
    </div>
  );
};

export default Users;
