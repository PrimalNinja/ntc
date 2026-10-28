import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width':1500,'height':850})
        logs=[]
        pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)))
        pg.on('console', lambda m: logs.append('console '+m.type+': '+m.text) if m.type in ('error','warning') else None)
        pg.on('dialog', lambda d: (logs.append('DIALOG '+d.message.replace('\n',' | ')), asyncio.ensure_future(d.accept())))
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'ntc.html')) + '')
        await pg.wait_for_timeout(500)
        await pg.set_input_files('#ge-openfile', ['vbp/Demo.vbp','vbp/Main.bas','vbp/Counter.cls'])
        await pg.wait_for_timeout(800)
        print('files', await pg.locator('#ge-filelist tbody tr').all_inner_texts())
        print('name', await pg.locator('#ge-projectname').inner_text())
        print('errors', await pg.locator('#ge-errors').inner_text())
        await pg.select_option('#ge-example', label='Long self test (32 bit)')
        await pg.wait_for_timeout(800)
        print('long errors', repr(await pg.locator('#ge-errors').inner_text()), await pg.locator('#ge-stats').inner_text())
        print(logs)
        await b.close()
asyncio.run(main())
