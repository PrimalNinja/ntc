import os
import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width':1500,'height':850})
        logs=[]
        pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)))
        pg.on('console', lambda m: logs.append('console '+m.type+': '+m.text) if m.type in ('error','warning') else None)
        pg.on('dialog', lambda d: asyncio.ensure_future(d.accept()))
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'ntc.html')) + '')
        await pg.wait_for_timeout(500)
        opts = await pg.locator('#ge-example option').all_inner_texts()
        for o in opts:
            if not o.strip() or o.startswith('-'): continue
            await pg.select_option('#ge-example', label=o)
            await pg.wait_for_timeout(600)
            print(o, '|', repr((await pg.locator('#ge-errors').inner_text())[:80]), '|', await pg.locator('#ge-stats').inner_text(), '|', await pg.locator('#ge-time').inner_text())
        await pg.screenshot(path='./gui5.png')
        print(logs)
        await b.close()
asyncio.run(main())
