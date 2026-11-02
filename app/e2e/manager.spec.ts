import { expect, test } from '@playwright/test';
import {
  collectBrowserErrors,
  expectNoBrowserErrors,
  openRoute,
  signIn,
} from './helpers.js';

test('manager can open every workspace screen without browser errors', async ({
  page,
}) => {
  const errors = collectBrowserErrors(page);
  await signIn(page, 'manager');
  await expect(
    page.getByText('Operations command center', { exact: true }),
  ).toBeVisible();

  const routes = [
    ['Inventory master', 'manager/inventory', 'Inventory master'],
    ['QR operations', 'manager/scan', 'QR equipment operations'],
    ['Lending records', 'manager/loans', 'Active equipment loans'],
    ['Approval center', 'manager/approvals', 'Manager approval center'],
    ['Asset archives', 'manager/archives', 'Damaged & disposed archives'],
    [
      'Finance & depreciation',
      'manager/finance',
      'Finance & depreciation',
    ],
    ['Export center', 'manager/reports', 'Excel export center'],
    ['QR label studio', 'manager/qr-labels', 'QR label studio'],
    ['Audit center', 'manager/audit', 'Immutable audit center'],
    [
      'Account administration',
      'manager/accounts',
      'Employee account administration',
    ],
    ['Settings & rules', 'manager/settings', 'Settings & preferences'],
  ] as const;

  for (const [label, route, heading] of routes) {
    await openRoute(page, label, route, heading);
    await expect(page.getByText('Workspace route not found')).toHaveCount(0);
  }

  expectNoBrowserErrors(errors);
});
