import { expect, test } from '@playwright/test';
import {
  collectBrowserErrors,
  expectNoBrowserErrors,
  openRoute,
  signIn,
} from './helpers.js';

test('manager can search inventory, inspect an asset and change its view', async ({
  page,
}) => {
  const errors = collectBrowserErrors(page);
  await signIn(page, 'manager');
  await openRoute(
    page,
    'Inventory master',
    'manager/inventory',
    'Inventory master',
  );
  await page.waitForTimeout(250);

  const search = page.getByRole('textbox', {
    name: /Search asset ID, serial, description, part, borrower/i,
  });
  await search.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.type('Bearing Heater 22 kVA');
  const assetDescription = page.getByText('Bearing Heater 22 kVA');
  await expect(assetDescription).toBeVisible();

  await page
    .getByRole('cell')
    .filter({ hasText: 'Bearing Heater 22 kVA' })
    .click();
  await expect(page.getByText('ASSET PROFILE')).toBeVisible();
  await expect(
    page.getByText('TL-PULL-006', { exact: true }).last(),
  ).toBeVisible();
  await page.keyboard.press('Escape');

  await page.getByRole('button', { name: 'Card view' }).click();
  await expect(assetDescription).toBeVisible();
  expectNoBrowserErrors(errors);
});
