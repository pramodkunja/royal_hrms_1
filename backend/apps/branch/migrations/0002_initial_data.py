from django.db import migrations

STATES_AND_CITIES = [
    # (state_name, state_code, [cities])
    ('Andhra Pradesh', 'AP', [
        'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool',
        'Tirupati', 'Kadapa', 'Rajahmundry',
    ]),
    ('Arunachal Pradesh', 'AR', ['Itanagar', 'Naharlagun']),
    ('Assam', 'AS', ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Tezpur']),
    ('Bihar', 'BR', [
        'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur',
        'Purnia', 'Arrah', 'Darbhanga', 'Bihar Sharif',
    ]),
    ('Chhattisgarh', 'CG', ['Raipur', 'Bhilai', 'Durg', 'Bilaspur', 'Korba']),
    ('Goa', 'GA', ['Panaji', 'Margao', 'Vasco da Gama']),
    ('Gujarat', 'GJ', [
        'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot',
        'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar',
    ]),
    ('Haryana', 'HR', [
        'Faridabad', 'Gurgaon', 'Hisar', 'Rohtak',
        'Panipat', 'Karnal', 'Ambala', 'Yamunanagar',
    ]),
    ('Himachal Pradesh', 'HP', ['Shimla', 'Dharamsala', 'Manali', 'Mandi', 'Solan']),
    ('Jharkhand', 'JH', ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar']),
    ('Karnataka', 'KA', [
        'Bengaluru', 'Mysuru', 'Mangaluru', 'Hubli', 'Belagavi',
        'Shivamogga', 'Davanagere', 'Ballari', 'Kalaburagi', 'Tumakuru',
    ]),
    ('Kerala', 'KL', [
        'Thiruvananthapuram', 'Kochi', 'Kozhikode',
        'Thrissur', 'Kollam', 'Kannur', 'Alappuzha',
    ]),
    ('Madhya Pradesh', 'MP', [
        'Bhopal', 'Indore', 'Jabalpur', 'Gwalior',
        'Ujjain', 'Ratlam', 'Sagar', 'Satna',
    ]),
    ('Maharashtra', 'MH', [
        'Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad',
        'Solapur', 'Amravati', 'Navi Mumbai', 'Thane',
        'Kolhapur', 'Nanded', 'Latur', 'Akola', 'Chandrapur',
    ]),
    ('Manipur', 'MN', ['Imphal', 'Thoubal']),
    ('Meghalaya', 'ML', ['Shillong', 'Tura']),
    ('Mizoram', 'MZ', ['Aizawl', 'Lunglei']),
    ('Nagaland', 'NL', ['Kohima', 'Dimapur']),
    ('Odisha', 'OD', [
        'Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur', 'Puri',
    ]),
    ('Punjab', 'PB', [
        'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali',
    ]),
    ('Rajasthan', 'RJ', [
        'Jaipur', 'Jodhpur', 'Kota', 'Bikaner',
        'Ajmer', 'Udaipur', 'Bhilwara', 'Alwar', 'Sikar',
    ]),
    ('Sikkim', 'SK', ['Gangtok', 'Namchi']),
    ('Tamil Nadu', 'TN', [
        'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem',
        'Tirunelveli', 'Erode', 'Vellore', 'Tiruppur', 'Nagercoil',
        'Thanjavur', 'Dindigul',
    ]),
    ('Telangana', 'TG', [
        'Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar', 'Ramagundam',
    ]),
    ('Tripura', 'TR', ['Agartala', 'Udaipur']),
    ('Uttar Pradesh', 'UP', [
        'Lucknow', 'Kanpur', 'Agra', 'Varanasi', 'Meerut', 'Prayagraj',
        'Ghaziabad', 'Bareilly', 'Moradabad', 'Gorakhpur', 'Saharanpur',
        'Firozabad', 'Shahjahanpur', 'Mathura', 'Rampur', 'Aligarh',
        'Muzaffarnagar', 'Loni', 'Noida',
    ]),
    ('Uttarakhand', 'UK', ['Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Kashipur']),
    ('West Bengal', 'WB', [
        'Kolkata', 'Howrah', 'Durgapur', 'Asansol',
        'Siliguri', 'Bardhaman', 'Berhampore', 'Malda',
    ]),
    # Union Territories
    ('Andaman and Nicobar Islands', 'AN', ['Port Blair']),
    ('Chandigarh', 'CH', ['Chandigarh']),
    ('Dadra and Nagar Haveli and Daman and Diu', 'DN', ['Daman', 'Silvassa', 'Diu']),
    ('Delhi', 'DL', ['New Delhi', 'Delhi', 'Dwarka', 'Rohini', 'Shahdara']),
    ('Jammu and Kashmir', 'JK', ['Srinagar', 'Jammu', 'Sopore']),
    ('Ladakh', 'LA', ['Leh', 'Kargil']),
    ('Lakshadweep', 'LD', ['Kavaratti']),
    ('Puducherry', 'PY', ['Puducherry', 'Karaikal']),
]


def seed_states_cities(apps, schema_editor):
    State = apps.get_model('branch', 'State')
    City = apps.get_model('branch', 'City')

    for state_name, state_code, cities in STATES_AND_CITIES:
        state, _ = State.objects.get_or_create(
            name=state_name,
            defaults={'code': state_code, 'is_active': True},
        )
        for city_name in cities:
            City.objects.get_or_create(
                name=city_name,
                state=state,
                defaults={'is_active': True},
            )


def remove_states_cities(apps, schema_editor):
    State = apps.get_model('branch', 'State')
    State.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('branch', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_states_cities, remove_states_cities),
    ]
