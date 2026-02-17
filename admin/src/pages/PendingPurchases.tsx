import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { PendingTokenPurchase } from '../types';

const PendingPurchases = () => {
  const [purchases, setPurchases] = useState<PendingTokenPurchase[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>('all');

  useEffect(() => {
    fetchPurchases();
    
    // Subscribe to real-time updates
    const channel = supabase
      .channel('pending_purchases')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'token_purchases' },
        () => fetchPurchases()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchPurchases = async () => {
    try {
      const { data, error } = await supabase
        .from('pending_token_purchases')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPurchases(data || []);
    } catch (error) {
      console.error('Error fetching purchases:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleValidate = async (purchaseId: string) => {
    if (!confirm('Confirmer la validation de ce paiement ?')) return;

    try {
      const { error } = await supabase.rpc('validate_token_purchase', {
        p_purchase_id: purchaseId,
        p_admin_notes: 'Validé depuis le dashboard admin',
      });

      if (error) throw error;
      alert('Paiement validé avec succès !');
      fetchPurchases();
    } catch (error) {
      console.error('Error validating purchase:', error);
      alert('Erreur lors de la validation');
    }
  };

  const handleReject = async (purchaseId: string) => {
    const reason = prompt('Raison du rejet :');
    if (!reason) return;

    try {
      const { error } = await supabase.rpc('reject_token_purchase', {
        p_purchase_id: purchaseId,
        p_reason: reason,
      });

      if (error) throw error;
      alert('Paiement rejeté');
      fetchPurchases();
    } catch (error) {
      console.error('Error rejecting purchase:', error);
      alert('Erreur lors du rejet');
    }
  };

  const getTimeAgo = (dateString: string) => {
    const diff = Date.now() - new Date(dateString).getTime();
    const minutes = Math.floor(diff / 60000);
    if (minutes < 60) return `il y a ${minutes} min`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `il y a ${hours}h`;
    return `il y a ${Math.floor(hours / 24)}j`;
  };

  const getProviderIcon = (provider: string) => {
    if (provider.includes('MTN')) return '📱';
    if (provider.includes('MOOV')) return '💳';
    if (provider.includes('TOGOCOM')) return '🟠';
    return '💰';
  };

  if (loading) {
    return <div className="loading">Chargement...</div>;
  }

  return (
    <div className="pending-purchases">
      <div className="page-header">
        <h1>Achats en attente de validation</h1>
        <div className="filters">
          <button 
            className={filter === 'all' ? 'active' : ''}
            onClick={() => setFilter('all')}
          >
            Tous ({purchases.length})
          </button>
        </div>
      </div>

      {purchases.length === 0 ? (
        <div className="empty-state">
          <p>✅ Aucun achat en attente</p>
        </div>
      ) : (
        <div className="purchases-grid">
          {purchases.map((purchase) => (
            <div key={purchase.id} className="purchase-card">
              <div className="purchase-header">
                <div className="purchase-user">
                  <div className="user-avatar">👤</div>
                  <div>
                    <h3>{purchase.driver_name}</h3>
                    <p className="phone">{purchase.driver_phone}</p>
                  </div>
                </div>
                <span className="time-ago">{getTimeAgo(purchase.created_at)}</span>
              </div>

              <div className="purchase-details">
                <div className="detail-row">
                  <span className="label">Package:</span>
                  <span className="value">{purchase.package_name}</span>
                </div>
                <div className="detail-row">
                  <span className="label">Jetons:</span>
                  <span className="value">{purchase.total_tokens} 💎</span>
                </div>
                <div className="detail-row">
                  <span className="label">Montant:</span>
                  <span className="value amount">{purchase.total_amount} XOF</span>
                </div>
                <div className="detail-row">
                  <span className="label">Opérateur:</span>
                  <span className="value">
                    {getProviderIcon(purchase.mobile_money_provider)} {purchase.mobile_money_provider}
                  </span>
                </div>
              </div>

              {(purchase.sms_notification || purchase.whatsapp_notification) && (
                <div className="notifications">
                  {purchase.sms_notification && <span className="badge">📱 SMS activé</span>}
                  {purchase.whatsapp_notification && <span className="badge">💬 WhatsApp activé</span>}
                </div>
              )}

              <div className="purchase-actions">
                <button 
                  className="btn-validate"
                  onClick={() => handleValidate(purchase.id)}
                >
                  ✓ Valider
                </button>
                <button 
                  className="btn-reject"
                  onClick={() => handleReject(purchase.id)}
                >
                  ✗ Rejeter
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default PendingPurchases;
