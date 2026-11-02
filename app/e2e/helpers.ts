import { expect, Page } from '@playwright/test';

export type AppRole = 'manager' | 'lender';

export async function signIn(page: Page, role: AppRole): Promise<void> {
  await page.goto('/#/login', { waitUntil: 'networkidle', timeout: 240_000 });
  const accessibility = page.locator('flt-semantics-placeholder');
  await accessibility.waitFor({ state: 'attached', timeout: 240_000 });
  await accessibility.evaluate((element) => (element as HTMLElement).click());
  await expect(accessibility).toHaveCount(0);

  const demo = page.getByText(`Fill ${role} demo`, { exact: true });
  await expect(demo).toBeVisible({ timeout: 30_000 });
  await demo.click();
  await page.getByText('SIGN IN TO WORKSPACE', { exact: true }).click();
  const home = role === 'manager' ? 'manager/dashboard' : 'lender/workspace';
  await expect(page).toHaveURL(new RegExp(`/${home}$`));
}

export async function openRoute(
  page: Page,
  navLabel: string,
  route: string,
  heading: string,
): Promise<void> {
  await page.getByRole('button', { name: navLabel, exact: true }).click();
  await expect.poll(() => new URL(page.url()).hash).toBe(`#/${route}`);
  await expect(page.getByText(heading, { exact: true }).last()).toBeVisible();
}

export function collectBrowserErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  return errors;
}

export function expectNoBrowserErrors(errors: string[]): void {
  expect(errors, errors.join('\n\n')).toEqual([]);
}
