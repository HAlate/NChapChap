export interface PendingTokenPurchase {
  id: string;
  driver_id: string;
  driver_name: string;
  driver_phone: string;
  package_name: string;
  total_amount: number;
  total_tokens: number;
  mobile_money_provider: string;
  status: "pending" | "validated" | "rejected";
  created_at: string;
  security_code?: string;
  sms_notification: boolean;
  whatsapp_notification: boolean;
}

export interface User {
  id: string;
  full_name: string;
  phone: string;
  email?: string;
  user_type: "driver" | "restaurant" | "merchant" | "rider";
  created_at: string;
  is_visible?: boolean;
}

export interface TokenBalance {
  user_id: string;
  token_type: string;
  balance: number;
  last_updated: string;
}

export interface TokenPackage {
  id: string;
  name: string;
  token_amount: number;
  price_xof: number;
  token_type: string;
  is_active: boolean;
}
