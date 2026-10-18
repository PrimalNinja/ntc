import os
import asyncio, sys
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width':1500,'height':850})
        logs=[]
        pg.on('console', lambda m: logs.append('console '+m.type+': '+m.text))
        pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)))
        pg.on('dialog', lambda d: asyncio.ensure_future(d.accept()))
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'ntc.html')) + '')
        await pg.wait_for_timeout(800)
        await pg.screenshot(path='./gui1.png')
        rows = await pg.locator('#ge-filelist tbody tr').count()
        print('rows', rows)
        print('stats', await pg.locator('#ge-stats').inner_text())
        print('errors', await pg.locator('#ge-errors').inner_text())
        # pick class example
        await pg.select_option('#ge-example', label='Class project (2 files)')
        await pg.wait_for_timeout(600)
        rows = await pg.locator('#ge-filelist tbody tr').all_inner_texts()
        print('rows after example', rows)
        out = await pg.evaluate("m_strAsm")
        print('has p_counter', 'p_counter_add_c' in out, 'errors:', await pg.locator('#ge-errors').inner_text())
        # click second file
        await pg.locator('#ge-filelist tbody tr').nth(1).click()
        await pg.wait_for_timeout(300)
        print('editor file', await pg.locator('#ge-filename').inner_text())
        print('editor starts', (await pg.evaluate("m_objInput.getValue()"))[:40].replace('\n','|'))
        # make an error in this file and click it
        await pg.evaluate("m_objInput.setValue(m_objInput.getValue() + '\\nPublic Sub Bad()\\n  zork 1\\nEnd Sub\\n'); ntcFile(m_strSelId).text = m_objInput.getValue(); ntcRecompile();")
        await pg.wait_for_timeout(400)
        print('errors now', await pg.locator('#ge-errors').inner_text())
        await pg.locator('#ge-filelist tbody tr').nth(0).click()
        await pg.wait_for_timeout(200)
        await pg.locator('#ge-errors div').first.click()
        await pg.wait_for_timeout(200)
        print('after error click file', await pg.locator('#ge-filename').inner_text())
        # new module
        await pg.locator('.ge-operation-NEWMOD').click()
        await pg.wait_for_timeout(300)
        print('rows after new', await pg.locator('#ge-filelist tbody tr').all_inner_texts())
        # turbo mode
        await pg.select_option('#ge-mode', 'turbo')
        await pg.wait_for_timeout(300)
        print('stats turbo', await pg.locator('#ge-stats').inner_text())
        await pg.screenshot(path='./gui2.png')
        print('\n'.join(logs))
        await b.close()
asyncio.run(main())
