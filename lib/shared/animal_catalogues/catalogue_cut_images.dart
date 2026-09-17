// Illustrative reference photographs, mapped to exact animal and cut names.
// Sources are recorded in docs/catalogue-image-sources.json.
const catalogueCutImages = <String, String>{
  "BEEF:chuck": "assets/images/cutlink_beef_00.webp",
  "BEEF:chuck roll": "assets/images/cutlink_beef_00.webp",
  "BEEF:chuck tender": "assets/images/cutlink_beef_01.webp",
  "BEEF:scotch fillet": "assets/images/cutlink_beef_02.webp",
  "BEEF:cube roll": "assets/images/cutlink_beef_02.webp",
  "BEEF:striploin": "assets/images/cutlink_beef_03.webp",
  "BEEF:porterhouse": "assets/images/cutlink_beef_03.webp",
  "BEEF:rump": "assets/images/cutlink_beef_04.webp",
  "BEEF:d-rump": "assets/images/cutlink_beef_04.webp",
  "BEEF:rump cap": "assets/images/cutlink_beef_05.webp",
  "BEEF:picanha": "assets/images/cutlink_beef_05.webp",
  "BEEF:rost biff": "assets/images/cutlink_beef_06.webp",
  "BEEF:rostbiff": "assets/images/cutlink_beef_06.webp",
  "BEEF:tri tip": "assets/images/cutlink_beef_07.webp",
  "BEEF:tenderloin": "assets/images/cutlink_beef_08.webp",
  "BEEF:eye fillet": "assets/images/cutlink_beef_08.webp",
  "BEEF:butt tenderloin": "assets/images/cutlink_beef_09.webp",
  "BEEF:tenderloin butt": "assets/images/cutlink_beef_09.webp",
  "BEEF:short loin": "assets/images/cutlink_beef_10.webp",
  "BEEF:chuck short ribs": "assets/images/cutlink_beef_11.webp",
  "BEEF:short ribs": "assets/images/cutlink_beef_12.webp",
  "BEEF:back rib": "assets/images/cutlink_beef_13.webp",
  "BEEF:back ribs": "assets/images/cutlink_beef_13.webp",
  "BEEF:oyster blade": "assets/images/cutlink_beef_14.webp",
  "BEEF:bolar blade": "assets/images/cutlink_beef_15.webp",
  "BEEF:topside cap on": "assets/images/cutlink_beef_16.webp",
  "BEEF:topside cap off": "assets/images/cutlink_beef_17.webp",
  "BEEF:eye round": "assets/images/cutlink_beef_18.webp",
  "BEEF:girello": "assets/images/cutlink_beef_18.webp",
  "BEEF:outside": "assets/images/cutlink_beef_19.webp",
  "BEEF:outside flat": "assets/images/cutlink_beef_20.webp",
  "BEEF:flank steak": "assets/images/cutlink_beef_21.webp",
  "BEEF:flap meat": "assets/images/cutlink_beef_22.webp",
  "BEEF:brisket navel end": "assets/images/cutlink_beef_23.webp",
  "BEEF:brisket point end": "assets/images/cutlink_beef_24.webp",
  "BEEF:brisket point": "assets/images/cutlink_beef_24.webp",
  "BEEF:heel muscle": "assets/images/cutlink_beef_25.webp",
  "BEEF:knuckle": "assets/images/cutlink_beef_26.webp",
  "BEEF:osso bucco": "assets/images/cutlink_beef_27.webp",
  "BEEF:osso buco": "assets/images/cutlink_beef_27.webp",
  "BEEF:beef cheek": "assets/images/cutlink_beef_28.webp",
  "BEEF:beef cheek meat": "assets/images/cutlink_beef_28.webp",
  "BEEF:cheek meat": "assets/images/cutlink_beef_28.webp",
  "BEEF:tendon": "assets/images/cutlink_beef_29.webp",
  "BEEF:feet": "assets/images/cutlink_beef_30.webp",
  "BEEF:tongue": "assets/images/cutlink_beef_31.webp",
  "BEEF:oxtail": "assets/images/cutlink_beef_32.webp",
  "BEEF:whole oxtail": "assets/images/cutlink_beef_32.webp",
  "BEEF:marrow bones": "assets/images/cutlink_beef_33.webp",
  "LAMB:frenched rack": "assets/images/cutlink_lamb_00.webp",
  "LAMB:fore shank": "assets/images/cutlink_lamb_01.webp",
  "LAMB:square-cut shoulder": "assets/images/cutlink_lamb_02.webp",
  "LAMB:short loin": "assets/images/cutlink_lamb_03.webp",
  "CHICKEN:breast fillet": "assets/images/cutlink_chicken_00.webp",
  "CHICKEN:skinless breast fillet": "assets/images/cutlink_chicken_00.webp",
  "CHICKEN:boneless skinless breast": "assets/images/cutlink_chicken_00.webp",
  "CHICKEN:whole wing": "assets/images/cutlink_chicken_01.webp",
  "CHICKEN:whole wings": "assets/images/cutlink_chicken_01.webp",
  "CHICKEN:wings": "assets/images/cutlink_chicken_01.webp",
  "VEAL:rump": "assets/images/cutlink_veal_00.webp",
  "VEAL:blade / clod": "assets/images/cutlink_veal_01.webp",
  "VEAL:heel muscle": "assets/images/cutlink_veal_02.webp",
  "VEAL:tri tip": "assets/images/cutlink_veal_03.webp",
  "VEAL:backstrap": "assets/images/cutlink_veal_04.webp",
};

String? catalogueImageAsset(Map<String, dynamic> product) {
  final animal = product['meat_animals'];
  final specification = product['meat_specifications'];
  if (animal is! Map || specification is! Map) return null;
  final code = animal['code']?.toString().trim().toUpperCase();
  final name = specification['name']?.toString().trim().toLowerCase();
  // A skinless breast photo must not represent an explicitly skin-on product.
  if (code == 'CHICKEN' && name == 'breast fillet') {
    final skin = product['chicken_skin']?.toString().toLowerCase();
    final bone = product['chicken_bone']?.toString().toLowerCase();
    if (skin == 'skin_on' || bone == 'bone_in') return null;
  }
  return catalogueCutImages['$code:$name'];
}
