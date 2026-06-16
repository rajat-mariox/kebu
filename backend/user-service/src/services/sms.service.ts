import axios from "axios";
import AppSettings from "../models/app-settings.model";

export type SmsAudience = "customers" | "vendors";

interface Msg91Settings {
  authKey: string;
  senderId: string;
  templateId: string;
  templateText: string;
  audience: string;
}

const SMS_KEYS = [
  "sms_api_key",
  "sms_sender_id",
  "sms_otp_template_id",
  "sms_otp_template",
  "sms_audience",
];

const loadSettings = async (): Promise<Msg91Settings> => {
  const docs = await AppSettings.find({ key: { $in: SMS_KEYS } });
  const map: Record<string, string> = {};
  for (const d of docs) map[d.key] = d.value || "";
  return {
    authKey: map.sms_api_key || "",
    senderId: map.sms_sender_id || "",
    templateId: map.sms_otp_template_id || "",
    templateText: map.sms_otp_template || "",
    audience: (map.sms_audience || "all").toLowerCase(),
  };
};

const isAudienceAllowed = (configured: string, target: SmsAudience): boolean => {
  if (configured === "all") return true;
  return configured === target;
};

/**
 * Send an OTP via MSG91. Silently no-ops (returning false) when:
 *   - the audience setting excludes the target group, OR
 *   - required MSG91 credentials are not configured.
 *
 * The caller should not block OTP login on a false return — the OTP is still
 * stored in Redis and the master OTP fallback remains available.
 */
export const sendOtpSms = async (
  mobileNumber: string,
  otp: string,
  audience: SmsAudience,
  countryCode: string = "+91",
): Promise<boolean> => {
  const cfg = await loadSettings();

  if (!isAudienceAllowed(cfg.audience, audience)) {
    console.log(`[SMS] Skipped: audience=${cfg.audience}, target=${audience}`);
    return false;
  }

  if (!cfg.authKey || !cfg.templateId) {
    console.warn("[SMS] MSG91 not configured (auth key or template id missing)");
    return false;
  }

  const cc = countryCode.replace(/\D/g, "") || "91";
  const localMobile = mobileNumber.replace(/\D/g, "");
  const fullMobile = localMobile.length === 10 ? `${cc}${localMobile}` : localMobile;

  try {
    // MSG91 Flow API. Variables (e.g. ##OTP##, ##var1##) go inside
    // recipients[i] alongside `mobiles`. The endpoint will substitute any
    // matching ##varN## or ##OTP## placeholder present in the approved
    // template body.
    const body: Record<string, unknown> = {
      template_id: cfg.templateId,
      recipients: [
        {
          mobiles: fullMobile,
          OTP: otp,
          var1: otp,
          otp,
        },
      ],
    };
    if (cfg.senderId) body.sender = cfg.senderId;

    console.log(
      `[SMS] MSG91 Flow request → ${fullMobile} template_id=${cfg.templateId} sender=${cfg.senderId || "(none)"}`,
    );

    const res = await axios.post(
      "https://control.msg91.com/api/v5/flow",
      body,
      {
        headers: {
          authkey: cfg.authKey,
          accept: "application/json",
          "Content-Type": "application/json",
        },
        timeout: 10_000,
        validateStatus: () => true,
      },
    );

    const ok = res.data?.type === "success";
    console.log(
      `[SMS] MSG91 Flow response (status=${res.status}) to ${fullMobile}:`,
      JSON.stringify(res.data),
    );
    if (!ok) {
      console.warn("[SMS] MSG91 non-success response body:", res.data);
    }
    return ok;
  } catch (err: any) {
    console.error(
      "[SMS] MSG91 request failed:",
      err?.response?.data || err?.message,
    );
    return false;
  }
};
