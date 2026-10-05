// Dependency-free generator for the checked-in Xcode project.
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '../ios');
const objects = [];
let counter = 1;
const id = () => (counter++).toString(16).toUpperCase().padStart(24, '0');
const add = (key, value) => objects.push(`${key} = { ${value} };`);
const project = id(), group = id(), products = id(), app = id(), test = id(), appProduct = id(), testProduct = id();
const appSources = id(), resources = id(), testSources = id(), frameworks = id(), testFrameworks = id();
const appConfigs = id(), testConfigs = id(), projectConfigs = id(), proxy = id(), dependency = id();
const files = [];
for (const [name, phase] of [['QMIntake/Core.swift', appSources], ['QMIntake/QMIntakeApp.swift', appSources], ['QMIntakeTests/IntakeTests.swift', testSources], ['QMIntake/Assets.xcassets', resources]]) {
  const ref = id(), build = id();
  add(ref, `isa = PBXFileReference; lastKnownFileType = ${name.endsWith('.swift') ? 'sourcecode.swift' : 'folder.assetcatalog'}; path = "${name}"; sourceTree = "<group>";`);
  add(build, `isa = PBXBuildFile; fileRef = ${ref};`); files.push({ref, build, phase});
}
add(appProduct, 'isa = PBXFileReference; explicitFileType = wrapper.application; path = QMIntake.app; sourceTree = BUILT_PRODUCTS_DIR;');
add(testProduct, 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = QMIntakeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
add(group, `isa = PBXGroup; children = (${files.map(f=>f.ref).join(',')},${products}); sourceTree = "<group>";`);
add(products, `isa = PBXGroup; children = (${appProduct},${testProduct}); name = Products; sourceTree = "<group>";`);
for (const [phase, type] of [[appSources,'Sources'],[testSources,'Sources'],[resources,'Resources'],[frameworks,'Frameworks'],[testFrameworks,'Frameworks']]) add(phase, `isa = PBX${type}BuildPhase; buildActionMask = 2147483647; files = (${files.filter(f=>f.phase===phase).map(f=>f.build).join(',')}); runOnlyForDeploymentPostprocessing = 0;`);
add(proxy, `isa = PBXContainerItemProxy; containerPortal = ${project}; proxyType = 1; remoteGlobalIDString = ${app}; remoteInfo = QMIntake;`);
add(dependency, `isa = PBXTargetDependency; target = ${app}; targetProxy = ${proxy};`);
add(app, `isa = PBXNativeTarget; buildConfigurationList = ${appConfigs}; buildPhases = (${appSources},${frameworks},${resources}); buildRules = (); dependencies = (); name = QMIntake; productName = QMIntake; productReference = ${appProduct}; productType = "com.apple.product-type.application";`);
add(test, `isa = PBXNativeTarget; buildConfigurationList = ${testConfigs}; buildPhases = (${testSources},${testFrameworks}); buildRules = (); dependencies = (${dependency}); name = QMIntakeTests; productName = QMIntakeTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
for (const [list, kind] of [[projectConfigs,'project'],[appConfigs,'app'],[testConfigs,'test']]) {
  const ids = [];
  for (const name of ['Debug','Release']) {
    const config = id(); ids.push(config);
    let settings = 'SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; ';
    if (kind === 'project') settings += `SWIFT_OPTIMIZATION_LEVEL = "${name==='Debug'?'-Onone':'-O'}"; ${name==='Debug'?'ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;':''}`;
    else settings += `PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = net.chateaulore.quartermaster.intake${kind==='test'?'.tests':''}; GENERATE_INFOPLIST_FILE = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.2.0; `;
    if (kind==='app') settings += 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; INFOPLIST_KEY_CFBundleDisplayName = "QM Intake"; INFOPLIST_KEY_NSCameraUsageDescription = "Take photos of items to add to Quartermaster inventory."; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";';
    if (kind==='test') settings += 'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/QMIntake.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/QMIntake"; BUNDLE_LOADER = "$(TEST_HOST)";';
    add(config, `isa = XCBuildConfiguration; buildSettings = { ${settings} }; name = ${name};`);
  }
  add(list, `isa = XCConfigurationList; buildConfigurations = (${ids.join(',')}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
add(project, `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${test} = { TestTargetID = ${app}; }; }; }; buildConfigurationList = ${projectConfigs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = ${group}; productRefGroup = ${products}; projectDirPath = ""; projectRoot = ""; targets = (${app},${test});`);
const directory = path.join(root,'QMIntake.xcodeproj'); fs.mkdirSync(path.join(directory,'xcshareddata/xcschemes'),{recursive:true});
fs.writeFileSync(path.join(directory,'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${project}; }\n`);
const ref = (target, name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="${name==='QMIntake'?'QMIntake.app':'QMIntakeTests.xctest'}" BlueprintName="${name}" ReferencedContainer="container:QMIntake.xcodeproj"/>`;
fs.writeFileSync(path.join(directory,'xcshareddata/xcschemes/QMIntake.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${ref(app,'QMIntake')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref(test,'QMIntakeTests')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref(app,'QMIntake')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref(app,'QMIntake')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>`);
