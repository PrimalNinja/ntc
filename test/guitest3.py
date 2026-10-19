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
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'ntc.html')) + '')
        await pg.wait_for_timeout(500)
        await pg.select_option('#ge-example', label='VB self test 2 (2 files)')
        await pg.wait_for_timeout(700)
        print('procs', (await pg.locator('#ge-proclist tbody tr').all_inner_texts())[:6])
        await pg.locator('#ge-proclist tbody tr').nth(2).click()
        await pg.wait_for_timeout(200)
        sel = await pg.evaluate("(function(){var o=$('#ge-input .ge-texteditor-code').get(0);return o.value.substring(o.selectionStart,o.selectionEnd);})()")
        print('selected line:', sel)
        await pg.locator('#ge-filelist tbody tr').nth(1).click()
        await pg.wait_for_timeout(300)
        print('procs file2', await pg.locator('#ge-proclist tbody tr').all_inner_texts())
        await pg.screenshot(path='./gui3.png')
        print(logs)
        await b.close()
asyncio.run(main())
