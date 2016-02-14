import requests
from bs4 import BeautifulSoup

url = "http://quote.eastmoney.com/3ban/sz832043.html"
resp = requests.get(url)
html = BeautifulSoup(resp.content, 'html.parser')
hxsjdiv = html.find_all('div', {'id': 'hxsjbox'})
hxsjtds = hxsjdiv[0].find_all('td')
for td in hxsjtds:
    print td.getText()

