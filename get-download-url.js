const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  try {
    await page.goto('https://windsurf.com/editor/releases');
    const downloadPromise = page.waitForEvent('download');
    await page.locator('text=/^Linux x64/').first().click();
    const download = await downloadPromise;
    const url = download.url();

    if (!url) {
        throw new Error('Could not capture the download URL from the download event.');
    }

    console.log(url);

  } catch (error) {
    console.error('Failed to get download URL:', error);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
