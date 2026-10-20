import os
import asyncio, json
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width':1400,'height':800})
        logs=[]
        pg.on('pageerror', lambda e: logs.append('PAGEERROR '+str(e)))
        pg.on('dialog', lambda d: asyncio.ensure_future(d.accept()))
        await pg.goto('file://' + os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'ntc.html')) + '')
        await pg.wait_for_timeout(500)
        await pg.set_input_files('#ge-openfile', ['/home/claude/scratch/t/cls/Counter.cls','/home/claude/proj/src/bas/sieve.bas'])
        await pg.wait_for_timeout(600)
        print('rows', await pg.locator('#ge-filelist tbody tr').all_inner_texts())
        json.dump({'version':1,'name':'proj2','mode':'turbo','files':[{'name':'A.bas','text':'Print Twice(4)\n'},{'name':'B.bas','text':'Public Function Twice(ByVal x As Integer) As Integer\n  Twice = x * 2\nEnd Function\n'}]}, open('t/p2.json','w'))
        await pg.set_input_files('#ge-openfile', ['/home/claude/scratch/t/p2.json'])
        await pg.wait_for_timeout(600)
        print('rows', await pg.locator('#ge-filelist tbody tr').all_inner_texts(), 'mode', await pg.input_value('#ge-mode'), 'name', await pg.locator('#ge-projectname').inner_text())
        print('errors', repr(await pg.locator('#ge-errors').inner_text()))
        asm = await pg.evaluate('m_strAsm')
        print('twice call', 'p_twice_c' in asm)
        # reload keeps the project
        await pg.reload(); await pg.wait_for_timeout(600)
        print('after reload', await pg.locator('#ge-filelist tbody tr').all_inner_texts())
        print(logs)
        await b.close()
asyncio.run(main())
