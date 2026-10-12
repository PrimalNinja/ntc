# platforms in the GUI: every example compiles on every platform, the org follows the platform
import os, re
import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width':1500,'height':850})
        logs=[]
        pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)))
        pg.on('dialog', lambda d: asyncio.ensure_future(d.accept()))
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'ntc.html')))
        await pg.wait_for_timeout(500)
        opts = [o for o in await pg.locator('#ge-example option').all_inner_texts() if o.strip() and not o.startswith('-')]
        for plat in ('cpc', 'cpcmin', 'cpcfw', 'cpm', 'test'):
            await pg.select_option('#ge-platform', plat)
            bad = []
            for o in opts:
                await pg.select_option('#ge-example', label=o)
                await pg.wait_for_timeout(300)
                e = (await pg.locator('#ge-errors').inner_text()).strip()
                only = re.search(r'\(((?:cpc|cpcmin|cpcfw|cpm|test)(?:, (?:cpc|cpcmin|cpcfw|cpm|test))*)\)$', o)
                if only and plat not in only.group(1).split(', '): continue    # the example names its platforms
                if e and 'Interrupt' not in e and 'Overlay' not in e: bad.append((o, e[:60]))
            asm = await pg.evaluate('m_strAsm')
            org = [l.strip() for l in asm.split('\n') if l.strip().startswith('org ')][:1]
            print(plat, org, 'errors:', bad)
        print(logs)
        await b.close()
asyncio.run(main())
