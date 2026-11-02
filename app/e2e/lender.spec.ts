import { expect, test } from '@playwright/test';
import {
  collectBrowserErrors,
  expectNoBrowserErrors,
  openRoute,
  signIn,
} from './helpers.js';

test('lender can access operational screens and cannot enter manager routes', async ({
  page,
}) => {
  const errors = collectBrowserErrors(page);
  await signIn(page, 'lender');
  await expect(
    page.getByText('Lending workspace', { exact: true }).last(),
  ).toBeVisible();

  const routes = [
    ['Scan equipment', 'lender/scan', 'QR equipment operations'],
    ['Loans & history', 'lender/loans', 'Active equipment loans'],
    ['Search inventory', 'lender/inventory', 'Inventory master'],
    ['Approval requests', 'lender/approvals', 'My approval requests'],
    ['Settings', 'lender/settings', 'Settings & preferences'],
  ] as const;

  for (const [label, route, heading] of routes) {
    await openRoute(page, label, route, heading);
  }

  await page.evaluate(() => {
    window.location.hash = '/manager/accounts';
  });
  await expect(page).toHaveURL(/#\/denied$/);
  await expect(page.getByText('Access denied', { exact: true })).toBeVisible();

  expectNoBrowserErrors(errors);
});
