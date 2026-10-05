type ExtraConfig = { extra?: { webAppUrl?: string } };

/** Test stub for expo-constants so Node tests avoid loading react-native. */
const Constants = {
  statusBarHeight: 0,
  expoConfig: undefined as ExtraConfig | undefined,
  manifest: undefined as ExtraConfig | undefined,
  manifest2: undefined as { extra?: { expoClient?: ExtraConfig } } | undefined,
};

export default Constants;
