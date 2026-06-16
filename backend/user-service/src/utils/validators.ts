export const validateName = (name: string): string | null => {
  if (!name || name.trim().length === 0) return "Name is required.";
  if (name.trim().length < 3) return "Name must be at least 3 characters.";
  if (!/^[a-zA-Z\s]+$/.test(name.trim()))
    return "Name can only contain letters and spaces.";
  return null;
};

export const validateEmail = (email: string): string | null => {
  if (!email || email.trim().length === 0) return "Email is required.";
  if (!/^[\w.\-]+@[\w.\-]+\.\w{2,}$/.test(email.trim()))
    return "Please enter a valid email address.";
  return null;
};

export const validatePhone = (phone: string): string | null => {
  if (!phone || phone.trim().length === 0) return "Phone number is required.";
  if (!/^[6-9]\d{9}$/.test(phone.trim()))
    return "Please enter a valid 10-digit mobile number.";
  return null;
};

export const validateAadhar = (aadhar: string): string | null => {
  if (!aadhar || aadhar.trim().length === 0)
    return "Aadhar number is required.";
  const cleaned = aadhar.replace(/\s/g, "");
  if (!/^\d{12}$/.test(cleaned))
    return "Aadhar number must be exactly 12 digits.";
  if (cleaned.startsWith("0") || cleaned.startsWith("1"))
    return "Please enter a valid Aadhar number.";
  return null;
};

export const validateDrivingLicence = (dl: string): string | null => {
  if (!dl || dl.trim().length === 0)
    return "Driving licence number is required.";
  if (!/^[A-Z]{2}\d{2}\s?\d{4}\s?\d{7}$/i.test(dl.trim()))
    return "Please enter a valid driving licence number (e.g., MH02 2020 1234567).";
  return null;
};

export const validateDate = (
  date: string,
  fieldName: string = "Date"
): string | null => {
  if (!date || date.trim().length === 0) return `${fieldName} is required.`;
  if (!/^\d{2}\/\d{2}\/\d{4}$/.test(date.trim()))
    return `Please enter a valid ${fieldName.toLowerCase()}.`;
  return null;
};

export const validateDOB = (dob: string): string | null => {
  const dateError = validateDate(dob, "Date of birth");
  if (dateError) return dateError;

  const parts = dob.trim().split("/");
  const day = parseInt(parts[0]);
  const month = parseInt(parts[1]) - 1;
  const year = parseInt(parts[2]);
  const dobDate = new Date(year, month, day);
  const now = new Date();
  let age = now.getFullYear() - dobDate.getFullYear();
  const monthDiff = now.getMonth() - dobDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dobDate.getDate()))
    age--;

  if (age < 18) return "Driver must be at least 18 years old.";
  if (age > 70) return "Please enter a valid date of birth.";
  return null;
};

export const validateAccountNumber = (acc: string): string | null => {
  if (!acc || acc.trim().length === 0) return "Account number is required.";
  if (!/^\d{9,18}$/.test(acc.trim()))
    return "Account number must be 9-18 digits.";
  return null;
};

export const validateIFSC = (ifsc: string): string | null => {
  if (!ifsc || ifsc.trim().length === 0) return "IFSC code is required.";
  if (!/^[A-Z]{4}0[A-Z0-9]{6}$/i.test(ifsc.trim()))
    return "Please enter a valid IFSC code (e.g., SBIN0001234).";
  return null;
};

export const validateZipCode = (zip: string): string | null => {
  if (!zip || zip.trim().length === 0)
    return "ZIP / Postal code is required.";
  if (!/^\d{6}$/.test(zip.trim()))
    return "Please enter a valid 6-digit PIN code.";
  return null;
};

export const validatePAN = (pan: string): string | null => {
  if (!pan || pan.trim().length === 0) return "PAN number is required.";
  if (!/^[A-Z]{5}\d{4}[A-Z]$/i.test(pan.trim()))
    return "Please enter a valid PAN number (e.g., ABCDE1234F).";
  return null;
};

export const validateAddress = (address: string): string | null => {
  if (!address || address.trim().length === 0) return "Address is required.";
  if (address.trim().length < 10) return "Please enter a complete address.";
  return null;
};
