CITY_CODE_MAP = {
    # Delhi / NCR
    'delhi': 'DEL',
    'new delhi': 'DEL',
    'noida': 'NOI',
    'ghaziabad': 'GZB',
    'gurgaon': 'GGN',
    'gurugram': 'GGN',
    'faridabad': 'FBD',
    'loni': 'LON',
    # Maharashtra
    'mumbai': 'MUM',
    'pune': 'PUN',
    'nagpur': 'NGP',
    'nashik': 'NSK',
    'aurangabad': 'AUR',
    'shambhajinagar': 'AUR',
    'solapur': 'SLR',
    'amravati': 'AMV',
    'navi mumbai': 'NMB',
    'thane': 'THN',
    'kolhapur': 'KLH',
    'nanded': 'NND',
    'latur': 'LTU',
    'akola': 'AKL',
    'chandrapur': 'CDR',
    # Karnataka
    'bengaluru': 'BLR',
    'bangalore': 'BLR',
    'mysuru': 'MYS',
    'mysore': 'MYS',
    'mangaluru': 'MNG',
    'mangalore': 'MNG',
    'hubli': 'HBL',
    'dharwad': 'DWD',
    'belagavi': 'BLG',
    'belgaum': 'BLG',
    'shivamogga': 'SHG',
    'shimoga': 'SHG',
    'davanagere': 'DVG',
    'ballari': 'BLY',
    'bellary': 'BLY',
    'kalaburagi': 'KLG',
    'gulbarga': 'KLG',
    'tumakuru': 'TKR',
    'tumkur': 'TKR',
    # Tamil Nadu
    'chennai': 'CHE',
    'madras': 'CHE',
    'coimbatore': 'CBE',
    'madurai': 'MDU',
    'tiruchirappalli': 'TRY',
    'trichy': 'TRY',
    'salem': 'SLM',
    'tirunelveli': 'TNV',
    'erode': 'ERD',
    'vellore': 'VLR',
    'tiruppur': 'TPR',
    'nagercoil': 'NGC',
    'thanjavur': 'TNJ',
    'dindigul': 'DDL',
    # Telangana
    'hyderabad': 'HYD',
    'warangal': 'WGL',
    'nizamabad': 'NZB',
    'khammam': 'KMM',
    'karimnagar': 'KMR',
    'ramagundam': 'RGD',
    # Andhra Pradesh
    'visakhapatnam': 'VZG',
    'vizag': 'VZG',
    'vijayawada': 'VJW',
    'guntur': 'GNT',
    'nellore': 'NLR',
    'kurnool': 'KNL',
    'tirupati': 'TPT',
    'kadapa': 'KDP',
    'rajahmundry': 'RJY',
    # Kerala
    'thiruvananthapuram': 'TVM',
    'trivandrum': 'TVM',
    'kochi': 'COK',
    'cochin': 'COK',
    'kozhikode': 'CLT',
    'calicut': 'CLT',
    'thrissur': 'TSR',
    'kollam': 'KLM',
    'kannur': 'CNN',
    'alappuzha': 'ALP',
    # Gujarat
    'ahmedabad': 'AMD',
    'surat': 'SRT',
    'vadodara': 'VDR',
    'rajkot': 'RJK',
    'bhavnagar': 'BHV',
    'jamnagar': 'JMN',
    'junagadh': 'JNG',
    'gandhinagar': 'GNR',
    # Rajasthan
    'jaipur': 'JAI',
    'jodhpur': 'JDH',
    'kota': 'KOT',
    'bikaner': 'BKN',
    'ajmer': 'AJM',
    'udaipur': 'UDR',
    'bhilwara': 'BHW',
    'alwar': 'ALW',
    'sikar': 'SKR',
    # Uttar Pradesh
    'lucknow': 'LKO',
    'kanpur': 'KNP',
    'agra': 'AGR',
    'varanasi': 'VNS',
    'meerut': 'MRT',
    'prayagraj': 'ALD',
    'allahabad': 'ALD',
    'ghaziabad': 'GZB',
    'bareilly': 'BRL',
    'moradabad': 'MRD',
    'gorakhpur': 'GKP',
    'saharanpur': 'SRE',
    'firozabad': 'FZD',
    'shahjahanpur': 'SHJ',
    'mathura': 'MTH',
    'rampur': 'RMP',
    'aligarh': 'ALG',
    'muzaffarnagar': 'MZN',
    # West Bengal
    'kolkata': 'KOL',
    'calcutta': 'KOL',
    'howrah': 'HWH',
    'durgapur': 'DGP',
    'asansol': 'ASN',
    'siliguri': 'SLG',
    'bardhaman': 'BWN',
    'berhampore': 'BMP',
    'malda': 'MLD',
    # Punjab
    'ludhiana': 'LDH',
    'amritsar': 'ASR',
    'jalandhar': 'JAL',
    'patiala': 'PTL',
    'bathinda': 'BTD',
    'mohali': 'MOH',
    # Haryana
    'hisar': 'HSR',
    'rohtak': 'ROH',
    'panipat': 'PNP',
    'karnal': 'KRL',
    'ambala': 'ABL',
    'yamunanagar': 'YMN',
    # Madhya Pradesh
    'bhopal': 'BPL',
    'indore': 'IDR',
    'jabalpur': 'JBL',
    'gwalior': 'GWL',
    'ujjain': 'UJJ',
    'ratlam': 'RTM',
    'sagar': 'SGR',
    'satna': 'STN',
    # Bihar
    'patna': 'PAT',
    'gaya': 'GAY',
    'bhagalpur': 'BGP',
    'muzaffarpur': 'MZF',
    'purnia': 'PNI',
    'arrah': 'ARH',
    'darbhanga': 'DBG',
    'bihar sharif': 'BSH',
    # Jharkhand
    'ranchi': 'RNC',
    'jamshedpur': 'JMP',
    'dhanbad': 'DHN',
    'bokaro': 'BKR',
    'deoghar': 'DGH',
    # Odisha
    'bhubaneswar': 'BBS',
    'cuttack': 'CTC',
    'rourkela': 'RKL',
    'berhampur': 'BRP',
    'brahmapur': 'BRP',
    'sambalpur': 'SBP',
    'puri': 'PRI',
    # Assam
    'guwahati': 'GUW',
    'dibrugarh': 'DIB',
    'silchar': 'SLC',
    'jorhat': 'JRH',
    # Chhattisgarh
    'raipur': 'RPR',
    'bhilai': 'BHI',
    'durg': 'DRG',
    'bilaspur': 'BLS',
    'korba': 'KRB',
    # Himachal Pradesh
    'shimla': 'SML',
    'dharamsala': 'DMS',
    'manali': 'MNL',
    'mandi': 'MDI',
    'solan': 'SOL',
    # Uttarakhand
    'dehradun': 'DDN',
    'haridwar': 'HDW',
    'roorkee': 'RKE',
    'haldwani': 'HLW',
    'kashipur': 'KSP',
    # Chandigarh
    'chandigarh': 'CHD',
    # Jammu & Kashmir
    'srinagar': 'SXR',
    'jammu': 'JAM',
    # Puducherry
    'puducherry': 'PND',
    'pondicherry': 'PND',
    # Tripura
    'agartala': 'AGT',
    # Manipur
    'imphal': 'IMP',
    # Meghalaya
    'shillong': 'SHI',
    # Mizoram
    'aizawl': 'AIZ',
    # Nagaland
    'kohima': 'KHM',
    'dimapur': 'DIM',
    # Goa
    'panaji': 'PNJ',
    'margao': 'MGO',
    'vasco da gama': 'VSC',
    # Andaman
    'port blair': 'PBR',
    # Ladakh
    'leh': 'LEH',
    'kargil': 'KGL',
    # Sikkim
    'gangtok': 'GTK',
    # Andhra Pradesh extras
    'nellore': 'NLR',
}


def get_city_prefix(city_name: str) -> str:
    city_lower = city_name.lower().strip()
    if city_lower in CITY_CODE_MAP:
        return CITY_CODE_MAP[city_lower]
    clean = ''.join(c for c in city_name.upper() if c.isalpha())
    return (clean[:3] if len(clean) >= 3 else clean.ljust(3, 'X'))


def generate_branch_code(city_name: str) -> str:
    """
    Returns next available branch code for a given city.
    First branch: DEL, subsequent: DEL-01, DEL-02, …
    Must be called inside an atomic block that also creates the Branch row.
    """
    from apps.branch.models import Branch

    prefix = get_city_prefix(city_name)

    existing = set(
        Branch.objects
        .select_for_update()
        .filter(branch_code__startswith=prefix)
        .values_list('branch_code', flat=True)
    )

    if prefix not in existing:
        return prefix

    max_num = max(
        (
            int(code[len(prefix) + 1:])
            for code in existing
            if code.startswith(prefix + '-') and code[len(prefix) + 1:].isdigit()
        ),
        default=0,
    )
    return f"{prefix}-{max_num + 1:02d}"
