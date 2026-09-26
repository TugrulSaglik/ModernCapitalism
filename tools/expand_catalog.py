"""One-time M12 catalog authoring helper; all runtime definitions remain JSON."""
import json
from pathlib import Path

p = Path('data/example_economy.json')
d = json.loads(p.read_text())
assert d['version'] == 12
d['version'] = 13
for id, year, prereq in [('materials',2000,[]),('food_processing',2000,[]),('textile_manufacturing',2000,[]),('woodworking',2000,[]),('advanced_materials',2010,['materials']),('automotive',2000,['materials']),('electric_vehicles',2018,['automotive','electronics'])]:
    d['technologies'].append(dict(id=id,year=year,prerequisites=prereq,research_work=600,research_cost=2500))
for id, name, demand, tech, sensitivity in [('materials','Industrial materials',0,'materials',0.4),('food','Food',180,'food_processing',0.25),('beverages','Beverages',90,'food_processing',0.35),('apparel','Apparel',75,'textile_manufacturing',0.6),('furniture','Furniture',35,'woodworking',0.7),('personal_care','Personal care',100,'materials',0.35),('automotive','Automotive',30,'automotive',1.0)]:
    d['categories'].append(dict(id=id,name=name,daily_demand=demand,technology=tech,purchase_frequency=1.0,income_sensitivity=sensitivity))
# Prices are integer cents; food/material units are commercial packs/lots.
groups = {
'materials': [('steel',800,420,{}),('plastic',300,140,{}),('glass',350,180,{}),('rubber',400,200,{}),('chemicals',450,200,{}),('fabric',700,350,{}),('lumber',1000,500,{}),('paper',250,110,{}),('packaging',700,100,{'paper':1,'plastic':1}),('grain',300,140,{}),('flour',600,100,{'grain':1}),('milk',500,240,{}),('coffee_beans',600,300,{})],
'food': [('bread',1800,200,{'flour':1,'packaging':1}),('breakfast_cereal',2300,250,{'grain':2,'packaging':1}),('cheese',2400,300,{'milk':2,'packaging':1}),('yogurt',1800,200,{'milk':1,'packaging':1}),('snacks',1800,200,{'flour':1,'packaging':1}),('pasta',2400,250,{'flour':2,'packaging':1}),('biscuits',2400,250,{'flour':1,'milk':1,'packaging':1}),('ice_cream',2700,350,{'milk':2,'packaging':1})],
'beverages': [('coffee',2400,300,{'coffee_beans':1,'packaging':1}),('bottled_drink',1700,300,{'packaging':1}),('fruit_juice',1900,500,{'packaging':1})],
'apparel': [('shirt',4000,600,{'fabric':2,'packaging':1}),('jeans',6000,900,{'fabric':3,'packaging':1}),('jacket',9500,1600,{'fabric':4,'plastic':1,'packaging':1}),('sneakers',7500,1000,{'fabric':2,'rubber':2,'packaging':1})],
'furniture': [('chair',10000,1800,{'lumber':2,'fabric':1}),('table',18000,3000,{'lumber':4,'steel':1}),('sofa',45000,7000,{'lumber':4,'fabric':6,'rubber':3}),('bed',35000,5000,{'lumber':5,'steel':2}),('mattress',23000,4000,{'fabric':4,'rubber':4}),('cabinet',28000,4500,{'lumber':6,'glass':2})],
'personal_care': [('soap',2400,300,{'chemicals':1,'packaging':1}),('shampoo',3200,400,{'chemicals':2,'packaging':1}),('toothpaste',2500,350,{'chemicals':1,'packaging':1}),('cosmetics',6000,1000,{'chemicals':3,'packaging':1}),('cleaning_product',2900,350,{'chemicals':2,'packaging':1})],
'automotive': [('compact_car',1600000,500000,{'steel':80,'glass':12,'rubber':12,'plastic':20,'motor':4,'electronics':4}),('suv',2400000,800000,{'steel':110,'glass':16,'rubber':18,'plastic':30,'motor':6,'electronics':6}),('electric_vehicle',3000000,850000,{'steel':90,'glass':14,'rubber':16,'plastic':24,'motor':5,'battery':120,'electronics':12})]
}
techs = dict(materials='materials',food='food_processing',beverages='food_processing',apparel='textile_manufacturing',furniture='woodworking',personal_care='advanced_materials',automotive='automotive')
for cat, rows in groups.items():
    for id, price, cost, inputs in rows:
        name=id.replace('_',' ').capitalize()
        if cat in ['food','beverages','personal_care'] or id in ['flour','milk','grain','coffee_beans']: name += ' (case)'
        if cat == 'materials' and not name.endswith('(case)'): name += ' (lot)'
        d['products'].append(dict(id=id,name=name,category=cat,technology='electric_vehicles' if id=='electric_vehicle' else techs[cat],reference_price=price,conversion_cost=cost,daily_demand=0 if cat=='materials' else 5 if cat=='automotive' else 30,inputs=inputs,base_quality=50))
def facility(id,name,cats,behavior,cost,cap,overhead,width=4,depth=3,style='factory'):
    products=[p['id'] for p in d['products'] if p['category'] in cats]
    f=dict(id=id,name=name,category='Retail' if behavior=='retail' else 'Industrial',behavior=behavior,style=style,cost=cost,capacity=cap,overhead=overhead,width=width,depth=depth,jobs=20,products=products,description='Compatible products share ordinary production, sourcing and logistics.' if behavior=='production' else 'Manage assortment, prices and suppliers for this sector.')
    if behavior=='retail': f.update(slots=8,categories=cats)
    d['facility_types'].append(f)
facility('materials_plant','Materials plant',['materials'],'production',3000000,100,4000)
facility('food_factory','Food factory',['food','beverages'],'production',2500000,100,3500)
facility('textile_factory','Textile factory',['apparel'],'production',3000000,45,4500)
facility('furniture_factory','Furniture factory',['furniture'],'production',4000000,20,6000)
facility('chemical_plant','Personal & household goods plant',['personal_care'],'production',3500000,70,4500)
facility('automobile_factory','Automobile factory',['automotive'],'production',15000000,2,20000,6,4,'automobile')
facility('supermarket','Supermarket',['food','beverages','personal_care'],'retail',2500000,100,3500,4,3,'department')
facility('clothing_store','Clothing store',['apparel'],'retail',2000000,45,4500,3,2,'shop')
facility('furniture_store','Furniture store',['furniture'],'retail',3000000,25,6000,4,3,'shop')
facility('car_dealership','Car dealership',['automotive'],'retail',7000000,3,10000,5,3,'dealer')
for f in d['facility_types']:
    if f['id']=='warehouse': f['products']=[p['id'] for p in d['products']]
    if f['id']=='corporate_headquarters': f['description']='Company headquarters for eight staff with payroll-funded management effects.'
p.write_text(json.dumps(d,indent=2)+'\n')
print(len(d['products']), 'products;', len(d['facility_types']), 'facilities;',len(d['technologies']),'technologies')
