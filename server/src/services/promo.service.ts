import { prisma } from '../config/database.js';
import { badRequest } from '../utils/errors.js';

export async function validatePromo(code: string) {
  const promo = await prisma.promoCode.findUnique({ where: { code } });
  if (!promo || !promo.isActive) throw badRequest('Invalid promo code');
  const now = new Date();
  if (now < promo.validFrom || now > promo.validUntil) throw badRequest('Promo code expired');
  if (promo.usedCount >= promo.maxUses) throw badRequest('Promo code fully redeemed');
  return {
    valid: true,
    code: promo.code,
    discount_type: promo.discountType,
    discount_value: promo.discountValue,
  };
}
